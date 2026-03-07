defmodule DecisionGraph.Projector.Write do
  @moduledoc false

  alias DecisionGraph.Domain.{CanonicalJson, EventTypes, StoredEvent}
  alias DecisionGraph.Error
  alias DecisionGraph.Projector.ContextGraph
  alias DecisionGraph.Projector.Digests
  alias DecisionGraph.Projector.{Edge, Node}
  alias DecisionGraph.Projector.SQL
  alias DecisionGraph.Projector.Support
  alias DecisionGraph.Store

  @default_batch_size 250

  @type sync_result :: %{
          projection_name: atom(),
          tenant_id: String.t(),
          last_log_seq: non_neg_integer(),
          processed_events: non_neg_integer(),
          pending_events: non_neg_integer()
        }

  @spec catch_up(atom() | String.t(), keyword()) :: {:ok, sync_result()} | {:error, Error.t()}
  def catch_up(projection_name, opts \\ []) do
    projection_name = Support.normalize_projection_name!(projection_name)
    tenant_id = Support.normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))

    batch_size =
      Support.normalize_batch_size(Keyword.get(opts, :batch_size, configured_batch_size()))

    until_log_seq = Support.normalize_optional_non_negative(Keyword.get(opts, :until_log_seq))

    Store.ensure_repo_started!()

    cursor = Store.get_projection_cursor(projection_name, tenant_id: tenant_id)
    tracker = load_trace_seq_tracker(tenant_id, cursor)

    result =
      Store.iter_event_batches(
        tenant_id: tenant_id,
        since_log_seq: cursor,
        until_log_seq: until_log_seq,
        batch_size: batch_size
      )
      |> Enum.reduce_while({tracker, cursor, 0}, fn events,
                                                    {batch_tracker, batch_cursor, processed} ->
        case project_batch(projection_name, tenant_id, events, batch_tracker) do
          {:ok, %{last_log_seq: last_log_seq, tracker: next_tracker}} ->
            {:cont, {next_tracker, last_log_seq, processed + length(events)}}

          {:error, %Error{} = error} ->
            {:halt, {:error, error, batch_cursor, processed}}
        end
      end)

    case result do
      {:error, error, last_log_seq, processed_events} ->
        {:error,
         %{
           error
           | details:
               Map.merge(error.details, %{
                 projection_name: projection_name,
                 tenant_id: tenant_id,
                 last_log_seq: last_log_seq,
                 processed_events: processed_events
               })
         }}

      {_tracker, last_log_seq, processed_events} ->
        event_log_last_seq = Store.get_last_log_seq(tenant_id: tenant_id)

        {:ok,
         %{
           projection_name: projection_name,
           tenant_id: tenant_id,
           last_log_seq: last_log_seq,
           processed_events: processed_events,
           pending_events: max(event_log_last_seq - last_log_seq, 0)
         }}
    end
  end

  @spec rebuild(atom() | String.t(), keyword()) :: {:ok, sync_result()} | {:error, Error.t()}
  def rebuild(projection_name, opts \\ []) do
    projection_name = Support.normalize_projection_name!(projection_name)
    tenant_id = Support.normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))

    case clear_projection(projection_name, tenant_id) do
      :ok -> catch_up(projection_name, Keyword.put(opts, :tenant_id, tenant_id))
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  @spec rebuild_all(keyword()) ::
          {:ok, [sync_result()]} | {:error, %{projection_name: atom(), error: Error.t()}}
  def rebuild_all(opts \\ []) do
    Enum.reduce_while(Support.projection_names(), {:ok, []}, fn projection_name, {:ok, acc} ->
      case rebuild(projection_name, opts) do
        {:ok, result} -> {:cont, {:ok, acc ++ [result]}}
        {:error, error} -> {:halt, {:error, %{projection_name: projection_name, error: error}}}
      end
    end)
  end

  @spec failure_recoverable?(Error.t()) :: boolean()
  def failure_recoverable?(%Error{code: :storage}), do: true
  def failure_recoverable?(_error), do: false

  @spec record_failure!(atom(), String.t(), StoredEvent.t(), Error.t(), keyword()) :: :ok
  def record_failure!(
        projection_name,
        tenant_id,
        %StoredEvent{} = event,
        %Error{} = error,
        opts \\ []
      ) do
    metadata =
      %{
        "processed_events" => Keyword.get(opts, :processed_events, 0),
        "recoverable" => Keyword.get(opts, :recoverable, false)
      }
      |> Map.merge(Map.get(error.details, :metadata, %{}))

    SQL.execute!(
      """
      INSERT INTO dg_projection_failures (
        id, tenant_id, projection_name, log_seq, trace_id, event_id, error_code, error_message,
        recoverable, retry_count, status, metadata_json, recorded_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'open', $11, $12)
      """,
      [
        Ecto.UUID.generate() |> Ecto.UUID.dump!(),
        tenant_id,
        Atom.to_string(Support.normalize_projection_name!(projection_name)),
        event.log_seq,
        event.trace_id,
        event.event_id,
        Atom.to_string(error.code),
        error.message,
        Keyword.get(opts, :recoverable, false),
        Keyword.get(opts, :retry_count, 0),
        CanonicalJson.canonicalize!(metadata),
        SQL.now_rfc3339()
      ]
    )
  end

  defp project_batch(_projection_name, _tenant_id, [], tracker) do
    {:ok, %{last_log_seq: 0, tracker: tracker}}
  end

  defp project_batch(projection_name, tenant_id, events, tracker) do
    try do
      case SQL.transaction(fn ->
             acquire_projection_lock!(tenant_id, projection_name)

             next_tracker =
               Enum.reduce(events, tracker, fn event, acc ->
                 project_event_in_tx(projection_name, tenant_id, event, acc)
               end)

             last_log_seq = List.last(events).log_seq

             :ok =
               Store.put_projection_cursor(projection_name, last_log_seq, tenant_id: tenant_id)

             :ok = resolve_failures!(tenant_id, projection_name, last_log_seq)
             :ok = refresh_projection_digests!(tenant_id)

             %{last_log_seq: last_log_seq, tracker: next_tracker}
           end) do
        {:ok, result} -> {:ok, result}
        {:error, %Error{} = error} -> {:error, error}
        {:error, other} -> {:error, Support.wrap_error(other)}
      end
    rescue
      error in Error -> {:error, error}
      error -> {:error, Support.wrap_error(error)}
    end
  end

  defp project_event_in_tx(projection_name, tenant_id, %StoredEvent{} = event, tracker) do
    try do
      validate_payload_hash!(event)
      expected_seq = validate_trace_seq!(tracker, event)

      case projection_name do
        :context_graph -> project_context_graph_event!(tenant_id, event)
        :trace_summary -> project_trace_summary_event!(tenant_id, event)
        :precedent_index -> project_precedent_event!(tenant_id, event)
      end

      Map.put(tracker, event.trace_id, expected_seq + 1)
    rescue
      error in Error ->
        reraise augment_error(error, event), __STACKTRACE__

      error ->
        reraise augment_error(Support.wrap_error(error), event), __STACKTRACE__
    end
  end

  defp project_context_graph_event!(tenant_id, event) do
    emission = ContextGraph.emit(event)
    Enum.each(emission.nodes, &insert_node!(tenant_id, &1))
    Enum.each(emission.edges, &insert_edge!(tenant_id, &1))
  end

  defp project_trace_summary_event!(tenant_id, event) do
    cond do
      event.event_type == EventTypes.trace_started() -> on_trace_started!(tenant_id, event)
      event.event_type == EventTypes.trace_finished() -> on_trace_finished!(tenant_id, event)
      true -> :ok
    end
  end

  defp project_precedent_event!(tenant_id, event) do
    cond do
      event.event_type == EventTypes.policy_evaluated() ->
        on_policy_evaluated!(tenant_id, event)

      event.event_type == EventTypes.trace_finished() ->
        build_precedent_index!(tenant_id, event.trace_id)

      true ->
        :ok
    end
  end

  defp insert_node!(tenant_id, %Node{} = node) do
    SQL.execute!(
      """
      INSERT INTO dg_cg_nodes (
        tenant_id, node_id, node_type, trace_id, log_seq, created_at, metadata_json
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (tenant_id, node_id) DO NOTHING
      """,
      [
        tenant_id,
        node.node_id,
        node.node_type,
        node.trace_id,
        node.log_seq,
        node.created_at,
        CanonicalJson.canonicalize!(node.attrs)
      ]
    )
  end

  defp insert_edge!(tenant_id, %Edge{} = edge) do
    ensure_node_exists!(
      tenant_id,
      edge.from_node_id,
      edge.trace_id,
      edge.log_seq,
      edge.created_at
    )

    ensure_node_exists!(tenant_id, edge.to_node_id, edge.trace_id, edge.log_seq, edge.created_at)

    SQL.execute!(
      """
      INSERT INTO dg_cg_edges (
        tenant_id, edge_id, edge_type, from_node_id, to_node_id, trace_id, log_seq, created_at, metadata_json
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      ON CONFLICT (tenant_id, edge_id) DO NOTHING
      """,
      [
        tenant_id,
        edge.edge_id,
        edge.edge_type,
        edge.from_node_id,
        edge.to_node_id,
        edge.trace_id,
        edge.log_seq,
        edge.created_at,
        CanonicalJson.canonicalize!(edge.attrs)
      ]
    )
  end

  defp ensure_node_exists!(tenant_id, node_id, trace_id, log_seq, created_at) do
    [node_type | rest] = String.split(node_id, ":", parts: 2)
    resolved_trace_id = if node_type == "trace" and rest != [], do: hd(rest), else: trace_id

    SQL.execute!(
      """
      INSERT INTO dg_cg_nodes (
        tenant_id, node_id, node_type, trace_id, log_seq, created_at, metadata_json
      )
      VALUES ($1, $2, $3, $4, $5, $6, '{}')
      ON CONFLICT (tenant_id, node_id) DO NOTHING
      """,
      [tenant_id, node_id, node_type, resolved_trace_id, log_seq, created_at]
    )
  end

  defp on_trace_started!(tenant_id, event) do
    primary_entity = Support.fetch(event.payload, "primary_entity", %{})

    SQL.execute!(
      """
      INSERT INTO dg_trace_summary (
        tenant_id, trace_id, workflow, title, primary_entity_type, primary_entity_system, primary_entity_id,
        outcome, started_at, finished_at, event_count, last_log_seq
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, NULL, $8, NULL, 1, $9)
      ON CONFLICT (tenant_id, trace_id) DO UPDATE
      SET event_count = dg_trace_summary.event_count + 1,
          last_log_seq = EXCLUDED.last_log_seq
      """,
      [
        tenant_id,
        event.trace_id,
        Support.fetch(event.payload, "workflow", ""),
        Support.fetch(event.payload, "title", ""),
        Support.fetch(primary_entity, "entity_type"),
        Support.fetch(primary_entity, "system"),
        Support.fetch(primary_entity, "entity_id"),
        event.occurred_at,
        event.log_seq
      ]
    )
  end

  defp on_trace_finished!(tenant_id, event) do
    SQL.execute!(
      """
      UPDATE dg_trace_summary
      SET outcome = $1,
          finished_at = $2,
          event_count = dg_trace_summary.event_count + 1,
          last_log_seq = $3
      WHERE tenant_id = $4 AND trace_id = $5
      """,
      [
        Support.fetch(event.payload, "outcome", "success"),
        event.occurred_at,
        event.log_seq,
        tenant_id,
        event.trace_id
      ]
    )
  end

  defp on_policy_evaluated!(tenant_id, event) do
    policy = Support.fetch(event.payload, "policy", %{})
    policy_id = Support.fetch(policy, "policy_id")
    policy_version = Support.fetch(policy, "policy_version")

    if Support.blank?(policy_id) or Support.blank?(policy_version) do
      raise Error,
        code: :schema_violation,
        message: "PolicyEvaluated requires policy_id and policy_version"
    end

    SQL.execute!(
      """
      INSERT INTO dg_policy_eval_index (
        tenant_id, index_id, trace_id, policy_id, policy_version, log_seq, created_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (tenant_id, index_id) DO NOTHING
      """,
      [
        tenant_id,
        "#{event.trace_id}:#{policy_id}:#{policy_version}:#{event.event_id}",
        event.trace_id,
        policy_id,
        policy_version,
        event.log_seq,
        event.occurred_at
      ]
    )
  end

  defp build_precedent_index!(tenant_id, trace_id) do
    rows =
      Store.get_trace_events(trace_id, tenant_id: tenant_id)
      |> Enum.sort_by(& &1.trace_seq)

    entries =
      rows
      |> Enum.reduce({nil, nil, nil, []}, fn event,
                                             {entity_type, entity_system, entity_id, acc} ->
        case event.event_type do
          "TraceStarted" when is_nil(entity_type) ->
            primary_entity = Support.fetch(event.payload, "primary_entity", %{})

            {
              Support.fetch(primary_entity, "entity_type"),
              Support.fetch(primary_entity, "system"),
              Support.fetch(primary_entity, "entity_id"),
              acc
            }

          "PolicyEvaluated" ->
            policy = Support.fetch(event.payload, "policy", %{})
            policy_id = Support.fetch(policy, "policy_id")
            policy_version = Support.fetch(policy, "policy_version")

            if Support.blank?(policy_id) or Support.blank?(policy_version) do
              raise Error,
                code: :schema_violation,
                message: "PolicyEvaluated requires policy_id and policy_version"
            end

            {
              entity_type,
              entity_system,
              entity_id,
              acc ++
                [
                  [
                    tenant_id,
                    event.event_id,
                    event.log_seq,
                    trace_id,
                    policy_id,
                    policy_version,
                    nil,
                    entity_type,
                    entity_system,
                    entity_id
                  ]
                ]
            }

          "ExceptionRequested" ->
            policy = Support.fetch(event.payload, "policy", %{})
            policy_id = Support.fetch(policy, "policy_id")
            policy_version = Support.fetch(policy, "policy_version")
            exception_id = Support.fetch(event.payload, "exception_id")

            if Support.blank?(policy_id) or Support.blank?(policy_version) or
                 Support.blank?(exception_id) do
              raise Error,
                code: :schema_violation,
                message: "ExceptionRequested requires policy and exception_id"
            end

            {
              entity_type,
              entity_system,
              entity_id,
              acc ++
                [
                  [
                    tenant_id,
                    event.event_id,
                    event.log_seq,
                    trace_id,
                    policy_id,
                    policy_version,
                    exception_id,
                    entity_type,
                    entity_system,
                    entity_id
                  ]
                ]
            }

          _ ->
            {entity_type, entity_system, entity_id, acc}
        end
      end)
      |> elem(3)

    SQL.execute!(
      "DELETE FROM dg_precedent_index WHERE tenant_id = $1 AND trace_id = $2",
      [tenant_id, trace_id]
    )

    Enum.each(entries, fn params ->
      SQL.execute!(
        """
        INSERT INTO dg_precedent_index (
          tenant_id, source_event_id, log_seq, trace_id, policy_id, policy_version,
          exception_id, primary_entity_type, primary_entity_system, primary_entity_id
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        ON CONFLICT (tenant_id, source_event_id) DO NOTHING
        """,
        params
      )
    end)
  end

  defp clear_projection(projection_name, tenant_id) do
    try do
      case SQL.transaction(fn ->
             acquire_projection_lock!(tenant_id, projection_name)

             case projection_name do
               :context_graph ->
                 :ok = SQL.execute!("DELETE FROM dg_cg_edges WHERE tenant_id = $1", [tenant_id])
                 :ok = SQL.execute!("DELETE FROM dg_cg_nodes WHERE tenant_id = $1", [tenant_id])

               :trace_summary ->
                 :ok =
                   SQL.execute!("DELETE FROM dg_trace_summary WHERE tenant_id = $1", [tenant_id])

               :precedent_index ->
                 :ok =
                   SQL.execute!("DELETE FROM dg_precedent_index WHERE tenant_id = $1", [tenant_id])

                 :ok =
                   SQL.execute!("DELETE FROM dg_policy_eval_index WHERE tenant_id = $1", [
                     tenant_id
                   ])
             end

             :ok = Store.put_projection_cursor(projection_name, 0, tenant_id: tenant_id)

             :ok =
               SQL.execute!(
                 "DELETE FROM dg_projection_failures WHERE tenant_id = $1 AND projection_name = $2",
                 [tenant_id, Atom.to_string(projection_name)]
               )

             :ok = refresh_projection_digests!(tenant_id)
           end) do
        {:ok, _result} -> :ok
        {:error, %Error{} = error} -> {:error, error}
        {:error, other} -> {:error, Support.wrap_error(other)}
      end
    rescue
      error in Error -> {:error, error}
      error -> {:error, Support.wrap_error(error)}
    end
  end

  defp refresh_projection_digests!(tenant_id) do
    digests = Digests.compute_all(tenant_id)

    Enum.each(Digests.projection_names(), fn projection_name ->
      cursor = Store.get_projection_cursor(projection_name, tenant_id: tenant_id)

      SQL.execute!(
        """
        INSERT INTO dg_projection_digests (tenant_id, projection_name, digest_value, last_log_seq, updated_at)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (tenant_id, projection_name) DO UPDATE
        SET digest_value = EXCLUDED.digest_value,
            last_log_seq = EXCLUDED.last_log_seq,
            updated_at = EXCLUDED.updated_at
        """,
        [
          tenant_id,
          Atom.to_string(projection_name),
          Map.fetch!(digests, projection_name),
          cursor,
          SQL.now_rfc3339()
        ]
      )
    end)

    full_cursor =
      Support.projection_names()
      |> Enum.map(&Store.get_projection_cursor(&1, tenant_id: tenant_id))
      |> Enum.min(fn -> 0 end)

    SQL.execute!(
      """
      INSERT INTO dg_projection_digests (tenant_id, projection_name, digest_value, last_log_seq, updated_at)
      VALUES ($1, 'full_projection', $2, $3, $4)
      ON CONFLICT (tenant_id, projection_name) DO UPDATE
      SET digest_value = EXCLUDED.digest_value,
          last_log_seq = EXCLUDED.last_log_seq,
          updated_at = EXCLUDED.updated_at
      """,
      [tenant_id, digests.full_projection, full_cursor, SQL.now_rfc3339()]
    )
  end

  defp resolve_failures!(tenant_id, projection_name, last_log_seq) do
    SQL.execute!(
      """
      UPDATE dg_projection_failures
      SET status = 'resolved',
          resolved_at = $4
      WHERE tenant_id = $1
        AND projection_name = $2
        AND status = 'open'
        AND log_seq <= $3
      """,
      [tenant_id, Atom.to_string(projection_name), last_log_seq, SQL.now_rfc3339()]
    )
  end

  defp load_trace_seq_tracker(_tenant_id, cursor) when cursor <= 0, do: %{}

  defp load_trace_seq_tracker(tenant_id, cursor) do
    SQL.query_all!(
      """
      SELECT trace_id, MAX(trace_seq) AS max_seq
      FROM dg_event_log
      WHERE tenant_id = $1 AND log_seq <= $2
      GROUP BY trace_id
      """,
      [tenant_id, cursor]
    )
    |> Map.new(fn row -> {row["trace_id"], row["max_seq"] + 1} end)
  end

  defp validate_payload_hash!(event) do
    expected_hash = CanonicalJson.compute_payload_hash!(event.payload)

    if event.payload_hash != expected_hash do
      raise Error,
        code: :conflict,
        message:
          "Payload hash mismatch for event #{event.event_id}: expected #{expected_hash}, got #{event.payload_hash}"
    end
  end

  defp validate_trace_seq!(tracker, event) do
    expected_seq = Map.get(tracker, event.trace_id, 0)

    if event.trace_seq != expected_seq do
      raise Error,
        code: :event_sequence_invalid,
        message:
          "trace_seq gap in trace #{event.trace_id}: expected #{expected_seq}, got #{event.trace_seq}",
        details: %{expected_trace_seq: expected_seq}
    end

    expected_seq
  end

  defp acquire_projection_lock!(tenant_id, projection_name) do
    _ =
      SQL.query_all!(
        "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
        ["#{tenant_id}:#{Atom.to_string(projection_name)}"]
      )

    :ok
  end

  defp configured_batch_size do
    Application.get_env(:dg_projector, :projection_batch_size, @default_batch_size)
  end

  defp augment_error(%Error{} = error, %StoredEvent{} = event) do
    %{
      error
      | details:
          Map.merge(error.details, %{
            event_id: event.event_id,
            log_seq: event.log_seq,
            trace_id: event.trace_id
          })
    }
  end
end
