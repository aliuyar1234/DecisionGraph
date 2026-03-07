defmodule DecisionGraph.Api.Traces do
  @moduledoc false

  alias DecisionGraph.Api.Errors
  alias DecisionGraph.Projector
  alias DecisionGraph.Projector.SQL
  alias DecisionGraph.Store

  @default_recent_events_limit 12
  @default_recent_limit 8
  @default_workflow_limit 5

  @spec get_trace(String.t(), keyword()) ::
          {:ok, map()} | {:error, DecisionGraph.Api.HttpError.t()}
  def get_trace(trace_id, opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)

    try do
      {:ok,
       %{
         events: Store.get_trace_events(trace_id, tenant_id: tenant_id),
         summary: Projector.get_trace_summary(trace_id, tenant_id: tenant_id)
       }}
    rescue
      error -> {:error, Errors.from_exception(error)}
    end
  end

  @spec list_recent_traces(pos_integer(), keyword()) ::
          {:ok, [map()]} | {:error, DecisionGraph.Api.HttpError.t()}
  def list_recent_traces(limit, opts \\ []) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)
    limit = normalize_recent_limit(limit)

    try do
      {:ok,
       SQL.query_all!(
         """
         SELECT trace_id, workflow, title, primary_entity_type, primary_entity_system, primary_entity_id,
                started_at, finished_at, outcome, event_count, last_log_seq
         FROM dg_trace_summary
         WHERE tenant_id = $1
         ORDER BY last_log_seq DESC, trace_id ASC
         LIMIT $2
         """,
         [tenant_id, limit]
       )
       |> Enum.map(&recent_trace_row/1)}
    rescue
      error -> {:error, Errors.from_exception(error)}
    end
  end

  @spec list_recent_events(pos_integer(), keyword()) ::
          {:ok, [map()]} | {:error, DecisionGraph.Api.HttpError.t()}
  def list_recent_events(limit \\ @default_recent_events_limit, opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)
    limit = normalize_event_limit(limit)

    try do
      {:ok,
       SQL.query_all!(
         """
         SELECT actor_id, actor_type, event_id, event_type, log_seq, occurred_at, payload_json,
                producer_id, recorded_at, source_subsystem, source_system, trace_id, trace_seq
         FROM dg_event_log
         WHERE tenant_id = $1
         ORDER BY log_seq DESC
         LIMIT $2
         """,
         [tenant_id, limit]
       )
       |> Enum.map(&recent_event_row/1)}
    rescue
      error -> {:error, Errors.from_exception(error)}
    end
  end

  @spec tenant_overview(keyword()) ::
          {:ok, map()} | {:error, DecisionGraph.Api.HttpError.t()}
  def tenant_overview(opts \\ []) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)

    workflow_limit =
      normalize_workflow_limit(Keyword.get(opts, :workflow_limit, @default_workflow_limit))

    try do
      summary_row =
        SQL.query_all!(
          """
          SELECT COUNT(*) AS trace_count,
                 COUNT(*) FILTER (WHERE finished_at IS NULL) AS active_trace_count,
                 COUNT(*) FILTER (WHERE finished_at IS NOT NULL) AS completed_trace_count,
                 MAX(COALESCE(finished_at, started_at)) AS last_trace_activity_at
          FROM dg_trace_summary
          WHERE tenant_id = $1
          """,
          [tenant_id]
        )
        |> List.first()
        |> Kernel.||(%{})

      event_row =
        SQL.query_all!(
          """
          SELECT COUNT(*) AS event_count, MAX(recorded_at) AS last_event_at
          FROM dg_event_log
          WHERE tenant_id = $1
          """,
          [tenant_id]
        )
        |> List.first()
        |> Kernel.||(%{})

      workflows =
        SQL.query_all!(
          """
          SELECT COALESCE(workflow, 'unknown') AS workflow, COUNT(*) AS trace_count
          FROM dg_trace_summary
          WHERE tenant_id = $1
          GROUP BY workflow
          ORDER BY COUNT(*) DESC, workflow ASC
          LIMIT $2
          """,
          [tenant_id, workflow_limit]
        )
        |> Enum.map(fn row ->
          %{
            trace_count: row["trace_count"],
            workflow: row["workflow"]
          }
        end)

      {:ok,
       %{
         active_trace_count: summary_row["active_trace_count"] || 0,
         completed_trace_count: summary_row["completed_trace_count"] || 0,
         event_count: event_row["event_count"] || 0,
         last_event_at: event_row["last_event_at"],
         last_trace_activity_at: summary_row["last_trace_activity_at"],
         tenant_id: tenant_id,
         trace_count: summary_row["trace_count"] || 0,
         workflows: workflows
       }}
    rescue
      error -> {:error, Errors.from_exception(error)}
    end
  end

  defp recent_trace_row(row) do
    %{
      event_count: row["event_count"],
      finished_at: row["finished_at"],
      last_log_seq: row["last_log_seq"],
      outcome: row["outcome"],
      primary_entity_id: row["primary_entity_id"],
      primary_entity_system: row["primary_entity_system"],
      primary_entity_type: row["primary_entity_type"],
      started_at: row["started_at"],
      status: recent_trace_status(row),
      title: row["title"],
      trace_id: row["trace_id"],
      workflow: row["workflow"]
    }
  end

  defp recent_event_row(row) do
    %{
      actor: %{
        actor_id: row["actor_id"],
        actor_type: row["actor_type"]
      },
      event_id: row["event_id"],
      event_type: row["event_type"],
      log_seq: row["log_seq"],
      occurred_at: row["occurred_at"],
      payload: Projector.Support.decode_json_map(row["payload_json"]),
      recorded_at: row["recorded_at"],
      source: %{
        producer_id: row["producer_id"],
        subsystem: row["source_subsystem"],
        system: row["source_system"]
      },
      trace_id: row["trace_id"],
      trace_seq: row["trace_seq"]
    }
  end

  defp recent_trace_status(%{"outcome" => outcome}) when is_binary(outcome) and outcome != "",
    do: outcome

  defp recent_trace_status(%{"finished_at" => finished_at}) when is_binary(finished_at),
    do: "finished"

  defp recent_trace_status(_row), do: "running"

  defp normalize_recent_limit(limit) when is_integer(limit) and limit > 0 do
    min(limit, 50)
  end

  defp normalize_recent_limit(limit) do
    limit
    |> to_string()
    |> Integer.parse()
    |> case do
      {value, ""} when value > 0 -> min(value, 50)
      _other -> @default_recent_limit
    end
  end

  defp normalize_event_limit(limit) when is_integer(limit) and limit > 0 do
    min(limit, 50)
  end

  defp normalize_event_limit(limit) do
    limit
    |> to_string()
    |> Integer.parse()
    |> case do
      {value, ""} when value > 0 -> min(value, 50)
      _other -> @default_recent_events_limit
    end
  end

  defp normalize_workflow_limit(limit) when is_integer(limit) and limit > 0 do
    min(limit, 10)
  end

  defp normalize_workflow_limit(limit) do
    limit
    |> to_string()
    |> Integer.parse()
    |> case do
      {value, ""} when value > 0 -> min(value, 10)
      _other -> @default_workflow_limit
    end
  end
end
