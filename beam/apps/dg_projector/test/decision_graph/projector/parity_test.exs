defmodule DecisionGraph.Projector.ParityTest do
  use DecisionGraph.Projector.DataCase, async: false

  @fixture_bundle_path Path.expand(
                         "../../../../../../tests/golden/reference_fixture_bundle.json",
                         __DIR__
                       )
  @bundle File.read!(@fixture_bundle_path) |> Jason.decode!()
  @scenarios @bundle["scenarios"]

  for scenario <- @scenarios do
    @scenario scenario
    @scenario_name scenario["scenario"]

    test "rebuild_all matches reference projection snapshot for #{@scenario_name}" do
      tenant_id = "projector:parity:" <> @scenario_name
      expected_cursor = @scenario["projection_snapshot"]["projection_cursor"]

      append_scenario!(@scenario, tenant_id)

      assert {:ok, results} = Engine.rebuild_all(tenant_id: tenant_id, batch_size: 2)

      assert Enum.map(results, & &1.projection_name) == [
               :context_graph,
               :trace_summary,
               :precedent_index
             ]

      assert Enum.all?(results, &(&1.last_log_seq == expected_cursor))

      assert cursors_for(tenant_id) == %{
               "context_graph" => expected_cursor,
               "precedent_index" => expected_cursor,
               "trace_summary" => expected_cursor
             }

      assert Digests.compute_all(tenant_id) == expected_digests(@scenario)

      summary = Projector.get_trace_summary(@scenario["trace_id"], tenant_id: tenant_id)

      assert trace_summary_to_map(summary) == @scenario["projection_snapshot"]["trace_summary"]
      assert summary.primary_entity_system == primary_entity_system(@scenario)

      assert context_graph_snapshot(tenant_id) ==
               @scenario["projection_snapshot"]["context_graph"]

      assert policy_eval_index_rows(tenant_id) ==
               @scenario["projection_snapshot"]["policy_eval_index"]

      assert precedent_index_rows(tenant_id) ==
               @scenario["projection_snapshot"]["precedent_index"]
    end
  end

  defp append_scenario!(scenario, tenant_id) do
    Enum.each(scenario["events"], fn attrs ->
      attrs
      |> EventEnvelope.new()
      |> Store.append_event(tenant_id: tenant_id)
    end)
  end

  defp cursors_for(tenant_id) do
    Store.list_projection_cursors(tenant_id: tenant_id)
    |> Map.new(fn row -> {row["projection_name"], row["last_log_seq"]} end)
  end

  defp expected_digests(scenario) do
    scenario["expected_digests"]
    |> Enum.map(fn {key, value} -> {String.to_atom(key), value} end)
    |> Map.new()
  end

  defp trace_summary_to_map(summary) do
    %{
      "event_count" => summary.event_count,
      "finished_at" => summary.finished_at,
      "last_log_seq" => summary.last_log_seq,
      "outcome" => summary.outcome,
      "primary_entity_id" => summary.primary_entity_id,
      "primary_entity_type" => summary.primary_entity_type,
      "started_at" => summary.started_at,
      "title" => summary.title,
      "trace_id" => summary.trace_id,
      "workflow" => summary.workflow
    }
  end

  defp primary_entity_system(scenario) do
    scenario["events"]
    |> Enum.find(&(&1["event_type"] == "TraceStarted"))
    |> get_in(["payload", "primary_entity", "system"])
  end

  defp policy_eval_index_rows(tenant_id) do
    SQL.query_all!(
      """
      SELECT created_at, index_id, log_seq, policy_id, policy_version, trace_id
      FROM dg_policy_eval_index
      WHERE tenant_id = $1
      ORDER BY log_seq ASC, index_id ASC
      """,
      [tenant_id]
    )
  end

  defp precedent_index_rows(tenant_id) do
    SQL.query_all!(
      """
      SELECT exception_id, log_seq, policy_id, policy_version, primary_entity_id,
             primary_entity_system, primary_entity_type, source_event_id, trace_id
      FROM dg_precedent_index
      WHERE tenant_id = $1
      ORDER BY source_event_id ASC
      """,
      [tenant_id]
    )
  end

  defp context_graph_snapshot(tenant_id) do
    nodes =
      SQL.query_all!(
        """
        SELECT node_id, node_type, trace_id, log_seq, created_at, metadata_json
        FROM dg_cg_nodes
        WHERE tenant_id = $1
        ORDER BY node_id ASC
        """,
        [tenant_id]
      )
      |> Enum.map(fn row ->
        %{
          "attrs" => Jason.decode!(row["metadata_json"]),
          "created_at" => row["created_at"],
          "log_seq" => row["log_seq"],
          "node_id" => row["node_id"],
          "node_type" => row["node_type"],
          "trace_id" => row["trace_id"]
        }
      end)

    edges =
      SQL.query_all!(
        """
        SELECT edge_id, edge_type, from_node_id, to_node_id, trace_id, log_seq, created_at, metadata_json
        FROM dg_cg_edges
        WHERE tenant_id = $1
        ORDER BY edge_id ASC
        """,
        [tenant_id]
      )
      |> Enum.map(fn row ->
        %{
          "attrs" => Jason.decode!(row["metadata_json"]),
          "created_at" => row["created_at"],
          "edge_id" => row["edge_id"],
          "edge_type" => row["edge_type"],
          "from_node_id" => row["from_node_id"],
          "log_seq" => row["log_seq"],
          "to_node_id" => row["to_node_id"],
          "trace_id" => row["trace_id"]
        }
      end)

    %{
      "edge_count" => length(edges),
      "edges" => edges,
      "node_count" => length(nodes),
      "nodes" => nodes
    }
  end
end
