defmodule DecisionGraph.Store do
  @moduledoc """
  Postgres-backed event store for the BEAM platform.
  """

  alias DecisionGraph.Domain.{CanonicalJson, EventEnvelope, StoredEvent, Validation}
  alias DecisionGraph.Error
  alias DecisionGraph.Observability
  alias DecisionGraph.Store.PreparedEvent
  alias DecisionGraph.Store.Repo
  alias Ecto.Adapters.SQL

  @default_batch_size 1_000
  @default_tenant_id "default"
  @projection_names [:context_graph, :trace_summary, :precedent_index]
  @trace_finished_event_type "TraceFinished"

  @type append_opt :: {:tenant_id, String.t()} | {:request_id, String.t()}
  @type list_opt ::
          {:event_type, String.t()}
          | {:limit, pos_integer()}
          | {:since_occurred_at, String.t()}
          | {:since_log_seq, non_neg_integer()}
          | {:tenant_id, String.t()}
          | {:trace_id, String.t()}
          | {:until_occurred_at, String.t()}
          | {:until_log_seq, non_neg_integer()}
  @type trace_opt ::
          {:limit, pos_integer()}
          | {:since_trace_seq, non_neg_integer()}
          | {:tenant_id, String.t()}
  @type batch_opt ::
          {:batch_size, pos_integer()}
          | {:event_type, String.t()}
          | {:since_occurred_at, String.t()}
          | {:since_log_seq, non_neg_integer()}
          | {:tenant_id, String.t()}
          | {:trace_id, String.t()}
          | {:until_occurred_at, String.t()}
          | {:until_log_seq, non_neg_integer()}

  @spec repo() :: module()
  def repo, do: Repo

  @spec repo_started?() :: boolean()
  def repo_started?, do: Process.whereis(Repo) != nil

  @spec ensure_repo_started!() :: :ok
  def ensure_repo_started! do
    case Process.whereis(Repo) do
      nil ->
        case Repo.start_link() do
          {:ok, _pid} ->
            :ok

          {:error, {:already_started, _pid}} ->
            :ok

          {:error, reason} ->
            raise Error, code: :storage, message: "Failed to start repo: #{inspect(reason)}"
        end

      _pid ->
        :ok
    end
  end

  @spec deployment_snapshot() :: map()
  def deployment_snapshot do
    config = Repo.config()

    %{
      database: Keyword.get(config, :database),
      hostname: Keyword.get(config, :hostname),
      maintenance_database: Keyword.get(config, :maintenance_database),
      pool_size: Keyword.get(config, :pool_size),
      projection_names: Enum.map(@projection_names, &Atom.to_string/1),
      repo_started?: repo_started?(),
      telemetry_prefix: Keyword.get(config, :telemetry_prefix, [])
    }
  end

  @spec append_event(EventEnvelope.t(), [append_opt()]) :: StoredEvent.t()
  def append_event(%EventEnvelope{} = envelope, opts \\ []) do
    ensure_repo_started!()

    envelope
    |> build_append_context(opts)
    |> do_append_event()
  end

  @spec get_trace_events(String.t(), [trace_opt()]) :: [StoredEvent.t()]
  def get_trace_events(trace_id, opts \\ []) when is_binary(trace_id) do
    ensure_repo_started!()

    tenant_id = normalize_optional_tenant_id(Keyword.get(opts, :tenant_id))

    since_trace_seq =
      normalize_non_negative_optional(Keyword.get(opts, :since_trace_seq), :since_trace_seq)

    limit = normalize_positive_optional(Keyword.get(opts, :limit), :limit)

    {clauses, params} =
      [
        {"trace_id = ?", trace_id},
        optional_clause(tenant_id, "tenant_id = ?"),
        optional_clause(since_trace_seq, "trace_seq > ?")
      ]
      |> collect_clauses()

    sql =
      "SELECT * FROM dg_event_log WHERE " <>
        Enum.join(clauses, " AND ") <>
        " ORDER BY trace_seq ASC" <>
        maybe_limit_sql(limit, length(params))

    params = append_limit_param(params, limit)

    sql
    |> query_all_rows!(params)
    |> Enum.map(&row_to_stored_event/1)
  end

  @spec list_events([list_opt()]) :: [StoredEvent.t()]
  def list_events(opts \\ []) do
    ensure_repo_started!()

    tenant_id = normalize_optional_tenant_id(Keyword.get(opts, :tenant_id))

    since_log_seq =
      normalize_non_negative_optional(Keyword.get(opts, :since_log_seq), :since_log_seq)

    until_log_seq =
      normalize_non_negative_optional(Keyword.get(opts, :until_log_seq), :until_log_seq)

    since_occurred_at =
      normalize_rfc3339_optional(Keyword.get(opts, :since_occurred_at), :since_occurred_at)

    until_occurred_at =
      normalize_rfc3339_optional(Keyword.get(opts, :until_occurred_at), :until_occurred_at)

    event_type = normalize_optional_string(Keyword.get(opts, :event_type))
    trace_id = normalize_optional_string(Keyword.get(opts, :trace_id))
    limit = normalize_positive_optional(Keyword.get(opts, :limit), :limit)

    validate_log_seq_bounds!(since_log_seq, until_log_seq)
    validate_occurred_at_bounds!(since_occurred_at, until_occurred_at)

    {clauses, params} =
      [
        optional_clause(tenant_id, "tenant_id = ?"),
        optional_clause(since_log_seq, "log_seq > ?"),
        optional_clause(until_log_seq, "log_seq <= ?"),
        optional_clause(since_occurred_at, "occurred_at > ?"),
        optional_clause(until_occurred_at, "occurred_at <= ?"),
        optional_clause(event_type, "event_type = ?"),
        optional_clause(trace_id, "trace_id = ?")
      ]
      |> collect_clauses("TRUE")

    sql =
      "SELECT * FROM dg_event_log WHERE " <>
        Enum.join(clauses, " AND ") <>
        " ORDER BY log_seq ASC" <>
        maybe_limit_sql(limit, length(params))

    params = append_limit_param(params, limit)

    sql
    |> query_all_rows!(params)
    |> Enum.map(&row_to_stored_event/1)
  end

  @spec iter_event_batches([batch_opt()]) :: Enumerable.t()
  def iter_event_batches(opts \\ []) do
    batch_size =
      opts
      |> Keyword.get(:batch_size, @default_batch_size)
      |> normalize_positive_optional(:batch_size)

    if is_nil(batch_size) do
      raise Error, code: :invalid_argument, message: "batch_size must be positive"
    end

    Stream.resource(
      fn ->
        normalize_non_negative_optional(Keyword.get(opts, :since_log_seq), :since_log_seq)
      end,
      &next_event_batch(&1, opts, batch_size),
      fn _state -> :ok end
    )
  end

  @spec get_last_log_seq(keyword()) :: non_neg_integer()
  def get_last_log_seq(opts \\ []) do
    ensure_repo_started!()

    tenant_id = normalize_optional_tenant_id(Keyword.get(opts, :tenant_id))
    {clauses, params} = [optional_clause(tenant_id, "tenant_id = ?")] |> collect_clauses("TRUE")

    sql =
      "SELECT COALESCE(MAX(log_seq), 0) AS max_log_seq FROM dg_event_log WHERE " <>
        Enum.join(clauses, " AND ")

    sql |> query_one_row!(params) |> Map.fetch!("max_log_seq")
  end

  @spec is_trace_finished(String.t(), keyword()) :: boolean()
  def is_trace_finished(trace_id, opts \\ []) when is_binary(trace_id) do
    ensure_repo_started!()
    tenant_id = normalize_optional_tenant_id(Keyword.get(opts, :tenant_id))
    trace_finished?(tenant_id, trace_id)
  end

  @spec get_next_trace_seq(String.t(), keyword()) :: non_neg_integer()
  def get_next_trace_seq(trace_id, opts \\ []) when is_binary(trace_id) do
    ensure_repo_started!()
    tenant_id = normalize_optional_tenant_id(Keyword.get(opts, :tenant_id))
    next_trace_seq(tenant_id, trace_id)
  end

  @spec get_projection_cursor(atom() | String.t(), keyword()) :: non_neg_integer()
  def get_projection_cursor(projection_name, opts \\ []) do
    ensure_repo_started!()

    tenant_id = normalize_tenant_id(Keyword.get(opts, :tenant_id, @default_tenant_id))
    projection_name = normalize_projection_name(projection_name)

    sql = """
    SELECT last_log_seq
    FROM dg_projection_cursors
    WHERE tenant_id = ? AND projection_name = ?
    LIMIT 1
    """

    case query_all_rows!(sql, [tenant_id, projection_name]) do
      [] -> 0
      [row] -> row["last_log_seq"]
    end
  end

  @spec put_projection_cursor(atom() | String.t(), non_neg_integer(), keyword()) :: :ok
  def put_projection_cursor(projection_name, last_log_seq, opts \\ []) do
    ensure_repo_started!()

    tenant_id = normalize_tenant_id(Keyword.get(opts, :tenant_id, @default_tenant_id))
    projection_name = normalize_projection_name(projection_name)
    last_log_seq = normalize_non_negative_optional(last_log_seq, :last_log_seq)
    updated_at = now_rfc3339()

    sql = """
    INSERT INTO dg_projection_cursors (tenant_id, projection_name, last_log_seq, updated_at)
    VALUES (?, ?, ?, ?)
    ON CONFLICT (tenant_id, projection_name)
    DO UPDATE
    SET last_log_seq = EXCLUDED.last_log_seq,
        updated_at = EXCLUDED.updated_at
    """

    _ = query_all_rows!(sql, [tenant_id, projection_name, last_log_seq, updated_at])
    :ok
  end

  @spec list_projection_cursors(keyword()) :: [map()]
  def list_projection_cursors(opts \\ []) do
    ensure_repo_started!()

    tenant_id = normalize_optional_tenant_id(Keyword.get(opts, :tenant_id))
    {clauses, params} = [optional_clause(tenant_id, "tenant_id = ?")] |> collect_clauses("TRUE")

    sql =
      "SELECT tenant_id, projection_name, last_log_seq, updated_at FROM dg_projection_cursors WHERE " <>
        Enum.join(clauses, " AND ") <> " ORDER BY tenant_id ASC, projection_name ASC"

    query_all_rows!(sql, params)
  end

  @spec clear(keyword()) :: :ok
  def clear(opts \\ []) do
    ensure_repo_started!()

    case normalize_optional_tenant_id(Keyword.get(opts, :tenant_id)) do
      nil ->
        _ =
          query_all_rows!(
            """
            TRUNCATE TABLE
              dg_workflow_notifications,
              dg_workflow_actions,
              dg_workflow_items,
              dg_workflow_runtime,
              dg_projection_failures,
              dg_projection_runs,
              dg_projection_digests,
              dg_precedent_index,
              dg_policy_eval_index,
              dg_trace_summary,
              dg_cg_edges,
              dg_cg_nodes,
              dg_projection_cursors,
              dg_event_log
            RESTART IDENTITY CASCADE
            """,
            []
          )

      tenant_id ->
        _ =
          query_all_rows!("DELETE FROM dg_workflow_notifications WHERE tenant_id = ?", [tenant_id])

        _ = query_all_rows!("DELETE FROM dg_workflow_actions WHERE tenant_id = ?", [tenant_id])
        _ = query_all_rows!("DELETE FROM dg_workflow_items WHERE tenant_id = ?", [tenant_id])
        _ = query_all_rows!("DELETE FROM dg_workflow_runtime WHERE tenant_id = ?", [tenant_id])
        _ = query_all_rows!("DELETE FROM dg_projection_failures WHERE tenant_id = ?", [tenant_id])
        _ = query_all_rows!("DELETE FROM dg_projection_runs WHERE tenant_id = ?", [tenant_id])
        _ = query_all_rows!("DELETE FROM dg_projection_digests WHERE tenant_id = ?", [tenant_id])
        _ = query_all_rows!("DELETE FROM dg_precedent_index WHERE tenant_id = ?", [tenant_id])
        _ = query_all_rows!("DELETE FROM dg_policy_eval_index WHERE tenant_id = ?", [tenant_id])
        _ = query_all_rows!("DELETE FROM dg_trace_summary WHERE tenant_id = ?", [tenant_id])
        _ = query_all_rows!("DELETE FROM dg_cg_edges WHERE tenant_id = ?", [tenant_id])
        _ = query_all_rows!("DELETE FROM dg_cg_nodes WHERE tenant_id = ?", [tenant_id])
        _ = query_all_rows!("DELETE FROM dg_projection_cursors WHERE tenant_id = ?", [tenant_id])
        _ = query_all_rows!("DELETE FROM dg_event_log WHERE tenant_id = ?", [tenant_id])
    end

    :ok
  end

  defp insert_event!(
         tenant_id,
         envelope,
         occurred_at,
         payload_json,
         payload_hash,
         tags_json,
         recorded_at
       ) do
    sql = """
    INSERT INTO dg_event_log (
      tenant_id,
      event_id,
      trace_id,
      trace_seq,
      event_type,
      occurred_at,
      recorded_at,
      producer_id,
      source_system,
      source_subsystem,
      actor_type,
      actor_id,
      correlation_id,
      causation_event_id,
      idempotency_key,
      schema_version,
      payload_json,
      payload_hash,
      tags_json
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    RETURNING *
    """

    params = [
      tenant_id,
      envelope.event_id,
      envelope.trace_id,
      envelope.trace_seq,
      envelope.event_type,
      occurred_at,
      recorded_at,
      envelope.source.producer_id,
      envelope.source.system,
      envelope.source.subsystem,
      envelope.actor.actor_type,
      envelope.actor.actor_id,
      envelope.correlation_id,
      envelope.causation_event_id,
      envelope.idempotency_key,
      envelope.schema_version,
      payload_json,
      payload_hash,
      tags_json
    ]

    sql
    |> query_one_row!(params)
    |> row_to_stored_event()
  end

  defp fetch_idempotent_event(tenant_id, producer_id, idempotency_key) do
    sql = """
    SELECT *
    FROM dg_event_log
    WHERE tenant_id = ? AND producer_id = ? AND idempotency_key = ?
    LIMIT 1
    """

    case query_all_rows!(sql, [tenant_id, producer_id, idempotency_key]) do
      [] -> nil
      [row] -> row_to_stored_event(row)
    end
  end

  defp validate_idempotent_reuse!(envelope, %StoredEvent{} = stored_event, payload_hash) do
    if stored_event.payload_hash != payload_hash do
      raise Error,
        code: :idempotency_conflict,
        message:
          "Idempotency key '#{envelope.idempotency_key}' already used with different payload"
    end

    mismatches =
      []
      |> maybe_mismatch(stored_event.trace_id != envelope.trace_id, "trace_id")
      |> maybe_mismatch(stored_event.event_type != envelope.event_type, "event_type")
      |> maybe_mismatch(stored_event.source != envelope.source, "source")
      |> maybe_mismatch(stored_event.actor != envelope.actor, "actor")
      |> maybe_mismatch(stored_event.correlation_id != envelope.correlation_id, "correlation_id")
      |> maybe_mismatch(
        stored_event.causation_event_id != envelope.causation_event_id,
        "causation_event_id"
      )
      |> maybe_mismatch(stored_event.schema_version != envelope.schema_version, "schema_version")
      |> maybe_mismatch(stored_event.tags != envelope.tags, "tags")

    if mismatches != [] do
      raise Error,
        code: :idempotency_conflict,
        message:
          "Idempotency key '#{envelope.idempotency_key}' already used with different metadata: #{Enum.join(mismatches, ", ")}",
        details: %{mismatches: mismatches}
    end

    :ok
  end

  defp maybe_mismatch(mismatches, true, field), do: mismatches ++ [field]
  defp maybe_mismatch(mismatches, false, _field), do: mismatches

  defp acquire_trace_lock!(tenant_id, trace_id) do
    _ =
      query_all_rows!(
        "SELECT pg_advisory_xact_lock(hashtextextended(?, 0))",
        ["#{tenant_id}:#{trace_id}"]
      )

    :ok
  end

  defp trace_finished?(tenant_id, trace_id) do
    {clauses, params} =
      [
        {"trace_id = ?", trace_id},
        {"event_type = ?", @trace_finished_event_type},
        optional_clause(tenant_id, "tenant_id = ?")
      ]
      |> collect_clauses()

    sql =
      "SELECT 1 AS finished FROM dg_event_log WHERE " <>
        Enum.join(clauses, " AND ") <> " LIMIT 1"

    query_all_rows!(sql, params) != []
  end

  defp next_trace_seq(tenant_id, trace_id) do
    {clauses, params} =
      [
        {"trace_id = ?", trace_id},
        optional_clause(tenant_id, "tenant_id = ?")
      ]
      |> collect_clauses()

    sql =
      "SELECT COALESCE(MAX(trace_seq) + 1, 0) AS next_trace_seq FROM dg_event_log WHERE " <>
        Enum.join(clauses, " AND ")

    sql |> query_one_row!(params) |> Map.fetch!("next_trace_seq")
  end

  defp recover_postgres_error(error, tenant_id, envelope, payload_hash) do
    constraint = postgres_detail(error, :constraint)
    message = postgres_detail(error, :message) || Exception.message(error)

    case constraint do
      "dg_event_log_idempotency_unique" ->
        recover_idempotency_conflict(tenant_id, envelope, payload_hash, constraint)

      "dg_event_log_trace_seq_unique" ->
        {:error,
         error(
           :event_sequence_invalid,
           "trace_seq #{envelope.trace_seq} already exists for trace",
           %{constraint: constraint}
         )}

      "dg_event_log_event_id_unique" ->
        {:error,
         error(
           :conflict,
           "event_id '#{envelope.event_id}' already exists",
           %{constraint: constraint}
         )}

      _ ->
        recover_postgres_message(message, error, envelope)
    end
  end

  defp build_append_context(envelope, opts) do
    tenant_id = normalize_tenant_id(Keyword.get(opts, :tenant_id, @default_tenant_id))
    prepared = PreparedEvent.prepare!(envelope)
    normalized_envelope = prepared.envelope
    payload_json = CanonicalJson.canonicalize!(normalized_envelope.payload)

    %{
      measurements: %{payload_bytes: byte_size(payload_json)},
      metadata: append_metadata(tenant_id, normalized_envelope, opts),
      normalized_envelope: normalized_envelope,
      # Preserve caller-provided event timestamps so projection rows and digests
      # match the Python reference fixtures byte-for-byte.
      occurred_at: normalized_envelope.occurred_at,
      payload_hash: prepared.payload_hash,
      payload_json: payload_json,
      recorded_at: now_rfc3339(prepared.recorded_at),
      started_at: System.monotonic_time(),
      tags_json: CanonicalJson.canonicalize!(normalized_envelope.tags),
      tenant_id: tenant_id
    }
  end

  defp do_append_event(context) do
    context
    |> execute_append_transaction()
    |> handle_append_transaction_result(context)
  rescue
    error in Postgrex.Error ->
      handle_postgres_append_error(error, context, __STACKTRACE__)

    error in Error ->
      emit_append_exception(context.started_at, context.measurements, context.metadata, error)
      reraise(error, __STACKTRACE__)
  end

  defp execute_append_transaction(
         %{
           normalized_envelope: envelope,
           payload_hash: payload_hash,
           tenant_id: tenant_id
         } = context
       ) do
    Repo.transaction(fn ->
      acquire_trace_lock!(tenant_id, envelope.trace_id)

      case fetch_idempotent_event(
             tenant_id,
             envelope.source.producer_id,
             envelope.idempotency_key
           ) do
        nil ->
          assert_trace_open!(tenant_id, envelope.trace_id)
          expected_seq = next_trace_seq(tenant_id, envelope.trace_id)
          Validation.validate_trace_sequence!(envelope, expected_seq)

          {:inserted,
           insert_event!(
             tenant_id,
             envelope,
             context.occurred_at,
             context.payload_json,
             payload_hash,
             context.tags_json,
             context.recorded_at
           )}

        stored ->
          validate_idempotent_reuse!(envelope, stored, payload_hash)
          {:reused, stored}
      end
    end)
  end

  defp handle_append_transaction_result({:ok, {:inserted, stored_event}}, context) do
    emit_append_stop(context.started_at, context.measurements, context.metadata)
    stored_event
  end

  defp handle_append_transaction_result({:ok, {:reused, stored_event}}, context) do
    emit_idempotency_reuse(context.metadata)

    emit_append_stop(
      context.started_at,
      Map.put(context.measurements, :reused, 1),
      context.metadata
    )

    stored_event
  end

  defp handle_append_transaction_result({:error, %Error{} = error}, context) do
    emit_append_exception(context.started_at, context.measurements, context.metadata, error)
    raise error
  end

  defp handle_postgres_append_error(error, context, stacktrace) do
    case recover_postgres_error(
           error,
           context.tenant_id,
           context.normalized_envelope,
           context.payload_hash
         ) do
      {:ok, stored_event} ->
        emit_idempotency_reuse(context.metadata)

        emit_append_stop(
          context.started_at,
          Map.put(context.measurements, :reused, 1),
          context.metadata
        )

        stored_event

      {:error, %Error{} = mapped_error} ->
        emit_append_exception(
          context.started_at,
          context.measurements,
          context.metadata,
          mapped_error
        )

        reraise(mapped_error, stacktrace)
    end
  end

  defp emit_idempotency_reuse(metadata) do
    Observability.emit([:store, :idempotency, :reuse], %{count: 1}, metadata)
  end

  defp assert_trace_open!(tenant_id, trace_id) do
    if trace_finished?(tenant_id, trace_id) do
      Repo.rollback(
        error(:conflict, "Trace '#{trace_id}' is already finished", %{trace_id: trace_id})
      )
    end
  end

  defp next_event_batch(:halt, _opts, _batch_size), do: {:halt, :halt}

  defp next_event_batch(cursor, opts, batch_size) do
    batch =
      opts
      |> Keyword.delete(:batch_size)
      |> Keyword.put(:since_log_seq, cursor)
      |> Keyword.put(:limit, batch_size)
      |> list_events()

    case batch do
      [] ->
        {:halt, :halt}

      events ->
        emit_read_batch(events, opts)
        {[events], next_batch_cursor(events, opts)}
    end
  end

  defp next_batch_cursor(events, opts) do
    next_cursor = List.last(events).log_seq
    until_log_seq = Keyword.get(opts, :until_log_seq)

    if until_log_seq && next_cursor >= until_log_seq do
      :halt
    else
      next_cursor
    end
  end

  defp recover_idempotency_conflict(tenant_id, envelope, payload_hash, constraint) do
    case fetch_idempotent_event(tenant_id, envelope.source.producer_id, envelope.idempotency_key) do
      nil ->
        {:error,
         error(
           :idempotency_conflict,
           "Idempotency key '#{envelope.idempotency_key}' already used",
           %{constraint: constraint}
         )}

      stored_event ->
        try do
          validate_idempotent_reuse!(envelope, stored_event, payload_hash)
          {:ok, stored_event}
        rescue
          mapped_error in Error -> {:error, mapped_error}
        end
    end
  end

  defp recover_postgres_message("trace_finished_lock", _error, envelope) do
    {:error, error(:conflict, "Trace '#{envelope.trace_id}' is already finished")}
  end

  defp recover_postgres_message("trace_started_requires_zero", _error, _envelope) do
    {:error, error(:event_sequence_invalid, "TraceStarted must have trace_seq=0")}
  end

  defp recover_postgres_message("first_event_must_be_trace_started", _error, envelope) do
    {:error,
     error(
       :event_sequence_invalid,
       "First event must be TraceStarted, got #{envelope.event_type}"
     )}
  end

  defp recover_postgres_message(message, error, envelope) when is_binary(message) do
    if String.starts_with?(message, "trace_seq_expected:") do
      [_, expected_seq] = String.split(message, ":")

      {:error,
       error(
         :event_sequence_invalid,
         "Expected trace_seq #{expected_seq}, got #{envelope.trace_seq}",
         %{expected_trace_seq: String.to_integer(expected_seq)}
       )}
    else
      {:error,
       error(:storage, "Database error: #{Exception.message(error)}", %{
         postgres: Map.get(error, :postgres, %{})
       })}
    end
  end

  defp emit_append_stop(started_at, measurements, metadata) do
    Observability.emit(
      [:store, :append, :stop],
      Map.put(measurements, :duration, System.monotonic_time() - started_at),
      metadata
    )
  end

  defp emit_append_exception(started_at, measurements, metadata, %Error{} = error) do
    Observability.emit(
      [:store, :append, :exception],
      Map.merge(measurements, %{count: 1, duration: System.monotonic_time() - started_at}),
      Map.merge(metadata, %{error_code: error.code})
    )
  end

  defp emit_read_batch(events, opts) do
    metadata =
      opts
      |> Keyword.take([:event_type, :tenant_id, :trace_id])
      |> Map.new()

    Observability.emit(
      [:store, :read_batch, :stop],
      %{
        count: 1,
        events: length(events),
        last_log_seq: List.last(events).log_seq
      },
      metadata
    )
  end

  defp row_to_stored_event(row) do
    tags = row["tags_json"] |> Jason.decode!()
    payload = row["payload_json"] |> Jason.decode!()

    StoredEvent.new(%{
      actor: %{
        actor_id: row["actor_id"],
        actor_type: row["actor_type"]
      },
      causation_event_id: row["causation_event_id"],
      correlation_id: row["correlation_id"],
      event_id: row["event_id"],
      event_type: row["event_type"],
      idempotency_key: row["idempotency_key"],
      log_seq: row["log_seq"],
      occurred_at: row["occurred_at"],
      payload: payload,
      payload_hash: row["payload_hash"],
      recorded_at: row["recorded_at"],
      schema_version: row["schema_version"],
      source: %{
        producer_id: row["producer_id"],
        subsystem: row["source_subsystem"],
        system: row["source_system"]
      },
      tags: tags,
      tenant_id: row["tenant_id"],
      trace_id: row["trace_id"],
      trace_seq: row["trace_seq"]
    })
  end

  defp query_one_row!(sql, params) do
    case query_all_rows!(sql, params) do
      [row | _rest] -> row
      [] -> %{}
    end
  end

  defp query_all_rows!(sql, params) do
    SQL.query!(Repo, normalize_sql_placeholders(sql), params)
    |> result_to_rows()
  end

  defp result_to_rows(%{columns: columns, rows: rows}) do
    columns = columns || []
    rows = rows || []

    Enum.map(rows, fn values ->
      columns
      |> Enum.zip(values)
      |> Map.new()
    end)
  end

  defp append_metadata(tenant_id, envelope, opts) do
    %{
      event_type: envelope.event_type,
      producer_id: envelope.source.producer_id,
      request_id: Keyword.get(opts, :request_id),
      tenant_id: tenant_id,
      trace_id: envelope.trace_id
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp optional_clause(nil, _sql), do: nil
  defp optional_clause(value, sql), do: {sql, value}

  defp collect_clauses(clauses, default_clause \\ nil) do
    {clauses, params} =
      clauses
      |> Enum.reject(&is_nil/1)
      |> Enum.map_reduce([], fn {sql, value}, params ->
        {String.replace(sql, "?", "$#{length(params) + 1}"), params ++ [value]}
      end)

    clauses =
      case {clauses, default_clause} do
        {[], nil} -> []
        {[], clause} -> [clause]
        {clauses, _default_clause} -> clauses
      end

    {clauses, params}
  end

  defp maybe_limit_sql(nil, _param_count), do: ""
  defp maybe_limit_sql(_limit, param_count), do: " LIMIT $#{param_count + 1}"

  defp append_limit_param(params, nil), do: params
  defp append_limit_param(params, limit), do: params ++ [limit]

  defp normalize_optional_tenant_id(nil), do: nil
  defp normalize_optional_tenant_id(tenant_id), do: normalize_tenant_id(tenant_id)

  defp normalize_tenant_id(tenant_id) when is_binary(tenant_id) do
    case String.trim(tenant_id) do
      "" -> raise Error, code: :invalid_argument, message: "tenant_id cannot be empty"
      normalized -> normalized
    end
  end

  defp normalize_tenant_id(tenant_id) do
    tenant_id
    |> to_string()
    |> normalize_tenant_id()
  end

  defp normalize_optional_string(nil), do: nil

  defp normalize_optional_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_optional_string(value), do: value |> to_string() |> normalize_optional_string()

  defp normalize_positive_optional(nil, _field), do: nil
  defp normalize_positive_optional(value, _field) when is_integer(value) and value > 0, do: value

  defp normalize_positive_optional(_value, field) do
    raise Error, code: :invalid_argument, message: "#{field} must be a positive integer"
  end

  defp normalize_non_negative_optional(nil, _field), do: nil

  defp normalize_non_negative_optional(value, _field) when is_integer(value) and value >= 0,
    do: value

  defp normalize_non_negative_optional(_value, field) do
    raise Error, code: :invalid_argument, message: "#{field} must be a non-negative integer"
  end

  defp normalize_rfc3339_optional(nil, _field), do: nil

  defp normalize_rfc3339_optional(value, field) when is_binary(value) do
    case DateTime.from_iso8601(String.trim(value)) do
      {:ok, datetime, _offset} ->
        now_rfc3339(datetime)

      {:error, _reason} ->
        raise Error, code: :invalid_argument, message: "#{field} must be an RFC3339 timestamp"
    end
  end

  defp normalize_rfc3339_optional(_value, field) do
    raise Error, code: :invalid_argument, message: "#{field} must be an RFC3339 timestamp"
  end

  defp normalize_projection_name(value) when is_atom(value) and value in @projection_names,
    do: Atom.to_string(value)

  defp normalize_projection_name(value) when is_binary(value) do
    normalized = String.trim(value)

    if normalized in Enum.map(@projection_names, &Atom.to_string/1) do
      normalized
    else
      raise Error, code: :invalid_argument, message: "Unknown projection '#{value}'"
    end
  end

  defp normalize_projection_name(value) do
    value
    |> to_string()
    |> normalize_projection_name()
  end

  defp postgres_detail(error, key) do
    error
    |> Map.get(:postgres, %{})
    |> Map.get(key)
  end

  defp error(code, message, details \\ %{}) do
    Error.exception(code: code, message: message, details: details)
  end

  defp now_rfc3339(datetime \\ DateTime.utc_now()) do
    datetime
    |> DateTime.truncate(:microsecond)
    |> format_rfc3339()
  end

  defp format_rfc3339(%DateTime{} = datetime) do
    base = Calendar.strftime(datetime, "%Y-%m-%dT%H:%M:%S")

    case elem(datetime.microsecond, 0) do
      0 ->
        base <> "Z"

      microsecond ->
        fraction =
          microsecond
          |> Integer.to_string()
          |> String.pad_leading(6, "0")
          |> String.trim_trailing("0")

        base <> "." <> fraction <> "Z"
    end
  end

  defp validate_log_seq_bounds!(nil, _until_log_seq), do: :ok
  defp validate_log_seq_bounds!(_since_log_seq, nil), do: :ok

  defp validate_log_seq_bounds!(since_log_seq, until_log_seq)
       when since_log_seq <= until_log_seq do
    :ok
  end

  defp validate_log_seq_bounds!(_since_log_seq, _until_log_seq) do
    raise Error,
      code: :invalid_argument,
      message: "since_log_seq must be <= until_log_seq"
  end

  defp validate_occurred_at_bounds!(nil, _until_occurred_at), do: :ok
  defp validate_occurred_at_bounds!(_since_occurred_at, nil), do: :ok

  defp validate_occurred_at_bounds!(since_occurred_at, until_occurred_at)
       when since_occurred_at <= until_occurred_at do
    :ok
  end

  defp validate_occurred_at_bounds!(_since_occurred_at, _until_occurred_at) do
    raise Error,
      code: :invalid_argument,
      message: "since_occurred_at must be <= until_occurred_at"
  end

  defp normalize_sql_placeholders(sql) do
    normalize_sql_placeholders(sql, 1, "")
  end

  defp normalize_sql_placeholders(<<>>, _index, acc), do: acc

  defp normalize_sql_placeholders(<<??, rest::binary>>, index, acc) do
    normalize_sql_placeholders(rest, index + 1, acc <> "$" <> Integer.to_string(index))
  end

  defp normalize_sql_placeholders(<<char::utf8, rest::binary>>, index, acc) do
    normalize_sql_placeholders(rest, index, acc <> <<char::utf8>>)
  end
end
