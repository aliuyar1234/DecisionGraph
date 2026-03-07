defmodule DecisionGraph.Projector.QueryParityTest do
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

    test "query surfaces match the frozen fixture outputs for #{@scenario_name}" do
      tenant_id = "projector:query-parity:" <> @scenario_name
      trace_id = @scenario["trace_id"]

      append_scenario!(@scenario, tenant_id)
      assert {:ok, _results} = Engine.rebuild_all(tenant_id: tenant_id, batch_size: 2)

      summary = Projector.get_trace_summary(trace_id, tenant_id: tenant_id)

      assert trace_summary_to_map(summary) == @scenario["projection_snapshot"]["trace_summary"]

      context =
        Projector.get_context_subgraph(
          %NodeRef{node_type: "trace", node_id: trace_id},
          tenant_id: tenant_id,
          filter: %GraphFilter{max_depth: 10, max_nodes: 500, max_edges: 500}
        )

      assert context.truncated == false
      assert context_subgraph_to_map(context) == expected_context_subgraph(@scenario)

      expected_trace_edges = expected_trace_edges(@scenario)
      actual_trace_edges = paginate_trace_edges(trace_id, tenant_id, 2)

      assert Enum.map(actual_trace_edges, &edge_to_map/1) == expected_trace_edges

      if length(expected_trace_edges) > 2 do
        first_page =
          Projector.list_node_edges(
            %NodeRef{node_type: "trace", node_id: trace_id},
            tenant_id: tenant_id,
            direction: :both,
            limit: 2
          )

        assert first_page.next_cursor != nil
      end

      assert Enum.map(
               Projector.find_precedents(%{}, tenant_id: tenant_id),
               &precedent_hit_to_map/1
             ) ==
               [expected_precedent_hit(@scenario)]

      if policy_hit = expected_policy_precedent_hit(@scenario) do
        assert Enum.map(
                 Projector.find_precedents(%{policy_id: policy_hit["policy_id"]},
                   tenant_id: tenant_id
                 ),
                 &precedent_hit_to_map/1
               ) == [policy_hit]

        assert Enum.map(
                 Projector.find_precedents(
                   %{
                     policy_id: policy_hit["policy_id"],
                     policy_version: policy_hit["policy_version"]
                   },
                   tenant_id: tenant_id
                 ),
                 &precedent_hit_to_map/1
               ) == [policy_hit]
      end
    end
  end

  test "projection-backed queries reject stale reads while event-log reads remain available" do
    scenario = Enum.find(@scenarios, &(&1["scenario"] == "dealdesk"))
    tenant_id = "projector:query-parity:stale"
    trace_id = scenario["trace_id"]

    append_scenario!(scenario, tenant_id)
    assert {:ok, _results} = Engine.rebuild_all(tenant_id: tenant_id, batch_size: 2)

    Store.append_event(stale_trace_started_event(), tenant_id: tenant_id)

    assert_projection_stale(fn ->
      Projector.get_trace_summary(trace_id, tenant_id: tenant_id)
    end)

    assert_projection_stale(fn ->
      Projector.get_context_subgraph(
        %NodeRef{node_type: "trace", node_id: trace_id},
        tenant_id: tenant_id,
        filter: %GraphFilter{max_depth: 1, max_nodes: 50, max_edges: 50}
      )
    end)

    assert_projection_stale(fn ->
      Projector.list_node_edges(
        %NodeRef{node_type: "trace", node_id: trace_id},
        tenant_id: tenant_id,
        direction: :both,
        limit: 10
      )
    end)

    assert_projection_stale(fn ->
      Projector.find_precedents(%{}, tenant_id: tenant_id)
    end)

    assert length(Store.list_events(tenant_id: tenant_id)) == scenario["event_count"] + 1

    assert Store.get_trace_events(trace_id, tenant_id: tenant_id)
           |> Enum.map(& &1.event_id) == Enum.map(scenario["events"], & &1["event_id"])
  end

  defp append_scenario!(scenario, tenant_id) do
    Enum.each(scenario["events"], fn attrs ->
      attrs
      |> EventEnvelope.new()
      |> Store.append_event(tenant_id: tenant_id)
    end)
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

  defp context_subgraph_to_map(context) do
    %{
      "edge_count" => length(context.edges),
      "edges" => Enum.map(context.edges, &edge_to_map/1),
      "node_count" => length(context.nodes),
      "nodes" => Enum.map(context.nodes, &node_to_map/1)
    }
  end

  defp node_to_map(node) do
    %{
      "attrs" => node.attrs,
      "created_at" => node.created_at,
      "log_seq" => node.log_seq,
      "node_id" => node.node_id,
      "node_type" => node.node_type,
      "trace_id" => node.trace_id
    }
  end

  defp edge_to_map(edge) do
    %{
      "attrs" => edge.attrs,
      "created_at" => edge.created_at,
      "edge_id" => edge.edge_id,
      "edge_type" => edge.edge_type,
      "from_node_id" => edge.from_node_id,
      "log_seq" => edge.log_seq,
      "to_node_id" => edge.to_node_id,
      "trace_id" => edge.trace_id
    }
  end

  defp precedent_hit_to_map(hit) do
    %{
      "finished_at" => hit.finished_at,
      "outcome" => hit.outcome,
      "policy_id" => hit.policy_id,
      "policy_version" => hit.policy_version,
      "title" => hit.title,
      "trace_id" => hit.trace_id,
      "workflow" => hit.workflow
    }
  end

  defp expected_precedent_hit(scenario) do
    summary = scenario["projection_snapshot"]["trace_summary"]

    %{
      "finished_at" => summary["finished_at"],
      "outcome" => summary["outcome"],
      "policy_id" => nil,
      "policy_version" => nil,
      "title" => summary["title"],
      "trace_id" => summary["trace_id"],
      "workflow" => summary["workflow"]
    }
  end

  defp expected_policy_precedent_hit(scenario) do
    scenario["projection_snapshot"]["precedent_index"]
    |> Enum.reject(&is_nil(&1["policy_id"]))
    |> Enum.sort_by(fn row ->
      {
        if(row["exception_id"], do: 0, else: 1),
        -row["log_seq"],
        row["source_event_id"]
      }
    end)
    |> List.first()
    |> case do
      nil ->
        nil

      row ->
        expected_precedent_hit(scenario)
        |> Map.put("policy_id", row["policy_id"])
        |> Map.put("policy_version", row["policy_version"])
    end
  end

  defp expected_trace_edges(scenario) do
    trace_key = "trace:" <> scenario["trace_id"]

    scenario["projection_snapshot"]["context_graph"]["edges"]
    |> Enum.filter(fn edge ->
      edge["from_node_id"] == trace_key or edge["to_node_id"] == trace_key
    end)
    |> Enum.sort_by(fn edge -> {edge["log_seq"], edge["edge_id"]} end)
  end

  defp expected_context_subgraph(scenario) do
    snapshot = scenario["projection_snapshot"]["context_graph"]
    center_key = "trace:" <> scenario["trace_id"]

    {visited_nodes, visited_edges} =
      traverse_snapshot_graph(
        snapshot["edges"],
        MapSet.new([center_key]),
        MapSet.new([center_key]),
        MapSet.new(),
        0,
        10
      )

    nodes =
      snapshot["nodes"]
      |> Enum.filter(&MapSet.member?(visited_nodes, &1["node_id"]))
      |> Enum.sort_by(& &1["node_id"])

    edges =
      snapshot["edges"]
      |> Enum.filter(&MapSet.member?(visited_edges, &1["edge_id"]))
      |> Enum.sort_by(& &1["edge_id"])

    %{
      "edge_count" => length(edges),
      "edges" => edges,
      "node_count" => length(nodes),
      "nodes" => nodes
    }
  end

  defp traverse_snapshot_graph(edges, frontier, visited_nodes, visited_edges, depth, max_depth) do
    if MapSet.size(frontier) == 0 or depth >= max_depth do
      {visited_nodes, visited_edges}
    else
      frontier_rows =
        edges
        |> Enum.filter(fn edge ->
          MapSet.member?(frontier, edge["from_node_id"]) or
            MapSet.member?(frontier, edge["to_node_id"])
        end)
        |> Enum.sort_by(& &1["edge_id"])

      {next_frontier, next_nodes, next_edges} =
        Enum.reduce(frontier_rows, {MapSet.new(), visited_nodes, visited_edges}, fn edge,
                                                                                    {frontier_acc,
                                                                                     nodes_acc,
                                                                                     edges_acc} ->
          if MapSet.member?(edges_acc, edge["edge_id"]) do
            {frontier_acc, nodes_acc, edges_acc}
          else
            neighbors = [edge["from_node_id"], edge["to_node_id"]]

            {next_frontier_acc, next_nodes_acc} =
              Enum.reduce(neighbors, {frontier_acc, nodes_acc}, fn neighbor,
                                                                   {neighbor_frontier_acc,
                                                                    neighbor_nodes_acc} ->
                if MapSet.member?(neighbor_nodes_acc, neighbor) do
                  {neighbor_frontier_acc, neighbor_nodes_acc}
                else
                  {
                    MapSet.put(neighbor_frontier_acc, neighbor),
                    MapSet.put(neighbor_nodes_acc, neighbor)
                  }
                end
              end)

            {next_frontier_acc, next_nodes_acc, MapSet.put(edges_acc, edge["edge_id"])}
          end
        end)

      traverse_snapshot_graph(
        edges,
        next_frontier,
        next_nodes,
        next_edges,
        depth + 1,
        max_depth
      )
    end
  end

  defp paginate_trace_edges(trace_id, tenant_id, limit, cursor \\ nil, acc \\ [])

  defp paginate_trace_edges(trace_id, tenant_id, limit, cursor, acc) do
    page =
      Projector.list_node_edges(
        %NodeRef{node_type: "trace", node_id: trace_id},
        tenant_id: tenant_id,
        direction: :both,
        cursor: cursor,
        limit: limit
      )

    next_acc = acc ++ page.edges

    case page.next_cursor do
      nil -> next_acc
      next_cursor -> paginate_trace_edges(trace_id, tenant_id, limit, next_cursor, next_acc)
    end
  end

  defp stale_trace_started_event do
    EventEnvelope.new(%{
      actor: %{actor_id: "phase9-query-parity", actor_type: "agent"},
      event_id: "phase9-query-stale-trace-started",
      event_type: "TraceStarted",
      idempotency_key: "phase9-query-stale-trace-started",
      occurred_at: "2026-03-07T18:00:00Z",
      payload: %{
        "primary_entity" => %{
          "entity_id" => "entity:phase9-query-stale",
          "entity_type" => "account",
          "system" => "crm"
        },
        "title" => "Phase 9 stale query check",
        "workflow" => "phase9_query_parity"
      },
      source: %{producer_id: "phase9-test", subsystem: "query", system: "tests"},
      trace_id: "phase9-query-stale-trace",
      trace_seq: 0
    })
  end

  defp assert_projection_stale(fun) do
    error = assert_raise Error, fun
    assert error.code == :projection_out_of_date
  end
end
