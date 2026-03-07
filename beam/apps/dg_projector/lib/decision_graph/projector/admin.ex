defmodule DecisionGraph.Projector.Admin do
  @moduledoc false

  alias DecisionGraph.Domain.CanonicalJson
  alias DecisionGraph.Error
  alias DecisionGraph.Projector.{ProjectionHealth, ProjectionStatus}
  alias DecisionGraph.Projector.SQL
  alias DecisionGraph.Projector.Support
  alias DecisionGraph.Store

  @spec projection_health(keyword()) :: ProjectionHealth.t()
  def projection_health(opts \\ []) do
    tenant_id = Support.normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))
    event_log_last_seq = Store.get_last_log_seq(tenant_id: tenant_id)

    digests =
      SQL.query_all!(
        """
        SELECT projection_name, digest_value, last_log_seq, updated_at
        FROM dg_projection_digests
        WHERE tenant_id = $1
        """,
        [tenant_id]
      )
      |> Map.new(fn row ->
        {row["projection_name"],
         %{
           digest: row["digest_value"],
           last_log_seq: row["last_log_seq"],
           updated_at: row["updated_at"]
         }}
      end)

    failure_counts =
      SQL.query_all!(
        """
        SELECT projection_name, COUNT(*) AS failure_count
        FROM dg_projection_failures
        WHERE tenant_id = $1 AND status = 'open'
        GROUP BY projection_name
        """,
        [tenant_id]
      )
      |> Map.new(fn row -> {row["projection_name"], row["failure_count"]} end)

    projections =
      Enum.map(Support.projection_names(), fn projection_name ->
        cursor = Store.get_projection_cursor(projection_name, tenant_id: tenant_id)
        digest_row = Map.get(digests, Atom.to_string(projection_name), %{})

        %ProjectionStatus{
          projection_name: projection_name,
          last_log_seq: cursor,
          pending_events: max(event_log_last_seq - cursor, 0),
          is_stale: cursor < event_log_last_seq,
          updated_at: Map.get(digest_row, :updated_at),
          digest: Map.get(digest_row, :digest),
          open_failures: Map.get(failure_counts, Atom.to_string(projection_name), 0)
        }
      end)

    open_runs =
      SQL.query_all!(
        """
        SELECT job_id, projection_name, mode, status, requested_at, started_at,
               processed_events, last_log_seq, until_log_seq
        FROM dg_projection_runs
        WHERE tenant_id = $1 AND status IN ('queued', 'running')
        ORDER BY requested_at ASC
        """,
        [tenant_id]
      )

    %ProjectionHealth{
      tenant_id: tenant_id,
      event_log_last_seq: event_log_last_seq,
      projections: projections,
      open_runs: open_runs,
      full_digest: digests |> Map.get("full_projection", %{}) |> Map.get(:digest)
    }
  end

  @spec list_runs(keyword()) :: [map()]
  def list_runs(opts \\ []) do
    tenant_id = Support.normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))

    SQL.query_all!(
      """
      SELECT job_id, tenant_id, projection_name, mode, status, requested_at, started_at, finished_at,
             since_log_seq, until_log_seq, processed_events, last_log_seq, error_code, error_message,
             metadata_json
      FROM dg_projection_runs
      WHERE tenant_id = $1
      ORDER BY requested_at DESC
      """,
      [tenant_id]
    )
  end

  @spec get_run(String.t()) :: map() | nil
  def get_run(job_id) do
    SQL.query_all!(
      """
      SELECT job_id, tenant_id, projection_name, mode, status, requested_at, started_at, finished_at,
             since_log_seq, until_log_seq, processed_events, last_log_seq, error_code, error_message,
             metadata_json
      FROM dg_projection_runs
      WHERE job_id = $1
      LIMIT 1
      """,
      [job_id]
    )
    |> List.first()
  end

  @spec create_run!(String.t(), atom() | String.t(), String.t(), keyword()) :: map()
  def create_run!(job_id, projection_name, mode, opts) do
    projection_name =
      case projection_name do
        :all -> "all"
        _ -> projection_name |> Support.normalize_projection_name!() |> Atom.to_string()
      end

    tenant_id = Support.normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))

    since_log_seq =
      Support.normalize_optional_non_negative(Keyword.get(opts, :since_log_seq)) || 0

    until_log_seq = Support.normalize_optional_non_negative(Keyword.get(opts, :until_log_seq))
    metadata_json = CanonicalJson.canonicalize!(Keyword.get(opts, :metadata, %{}))
    requested_at = SQL.now_rfc3339()

    SQL.execute!(
      """
      INSERT INTO dg_projection_runs (
        job_id, tenant_id, projection_name, mode, status, requested_at,
        since_log_seq, until_log_seq, metadata_json
      )
      VALUES ($1, $2, $3, $4, 'queued', $5, $6, $7, $8)
      """,
      [
        job_id,
        tenant_id,
        projection_name,
        mode,
        requested_at,
        since_log_seq,
        until_log_seq,
        metadata_json
      ]
    )

    get_run(job_id)
  end

  @spec mark_run_running!(String.t()) :: :ok
  def mark_run_running!(job_id) do
    SQL.execute!(
      """
      UPDATE dg_projection_runs
      SET status = 'running',
          started_at = COALESCE(started_at, $2)
      WHERE job_id = $1
      """,
      [job_id, SQL.now_rfc3339()]
    )
  end

  @spec mark_run_progress!(String.t(), non_neg_integer(), non_neg_integer()) :: :ok
  def mark_run_progress!(job_id, processed_events, last_log_seq) do
    SQL.execute!(
      """
      UPDATE dg_projection_runs
      SET processed_events = $2,
          last_log_seq = $3
      WHERE job_id = $1
      """,
      [job_id, processed_events, last_log_seq]
    )
  end

  @spec mark_run_completed!(String.t(), non_neg_integer(), non_neg_integer()) :: :ok
  def mark_run_completed!(job_id, processed_events, last_log_seq) do
    SQL.execute!(
      """
      UPDATE dg_projection_runs
      SET status = 'completed',
          finished_at = $2,
          processed_events = $3,
          last_log_seq = $4,
          error_code = NULL,
          error_message = NULL
      WHERE job_id = $1
      """,
      [job_id, SQL.now_rfc3339(), processed_events, last_log_seq]
    )
  end

  @spec mark_run_failed!(String.t(), Error.t(), non_neg_integer(), non_neg_integer()) :: :ok
  def mark_run_failed!(job_id, %Error{} = error, processed_events, last_log_seq) do
    SQL.execute!(
      """
      UPDATE dg_projection_runs
      SET status = 'failed',
          finished_at = $2,
          processed_events = $3,
          last_log_seq = $4,
          error_code = $5,
          error_message = $6
      WHERE job_id = $1
      """,
      [
        job_id,
        SQL.now_rfc3339(),
        processed_events,
        last_log_seq,
        Atom.to_string(error.code),
        error.message
      ]
    )
  end

  @spec mark_run_cancelled!(String.t(), non_neg_integer(), non_neg_integer()) :: :ok
  def mark_run_cancelled!(job_id, processed_events, last_log_seq) do
    SQL.execute!(
      """
      UPDATE dg_projection_runs
      SET status = 'cancelled',
          finished_at = $2,
          processed_events = $3,
          last_log_seq = $4
      WHERE job_id = $1
      """,
      [job_id, SQL.now_rfc3339(), processed_events, last_log_seq]
    )
  end

  @spec list_failures(keyword()) :: [map()]
  def list_failures(opts \\ []) do
    tenant_id = Support.normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))

    SQL.query_all!(
      """
      SELECT id, tenant_id, projection_name, log_seq, trace_id, event_id, error_code, error_message,
             recoverable, retry_count, status, metadata_json, recorded_at, resolved_at
      FROM dg_projection_failures
      WHERE tenant_id = $1
      ORDER BY recorded_at DESC, id DESC
      """,
      [tenant_id]
    )
  end
end
