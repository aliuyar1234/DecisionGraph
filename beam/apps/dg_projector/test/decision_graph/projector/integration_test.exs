defmodule DecisionGraph.Projector.IntegrationTest do
  use DecisionGraph.Projector.DataCase, async: false

  @fixture_bundle_path Path.expand(
                         "../../../../../../tests/golden/reference_fixture_bundle.json",
                         __DIR__
                       )
  @bundle File.read!(@fixture_bundle_path) |> Jason.decode!()
  @dealdesk Enum.find(@bundle["scenarios"], &(&1["scenario"] == "dealdesk"))

  test "catch_up resumes from durable cursor and projection health reports lag" do
    tenant_id = "projector:resume"
    expected_cursor = @dealdesk["projection_snapshot"]["projection_cursor"]

    append_scenario!(@dealdesk, tenant_id)

    assert {:ok, result} =
             Engine.catch_up(
               :trace_summary,
               tenant_id: tenant_id,
               batch_size: 2,
               until_log_seq: 4
             )

    assert result.last_log_seq == 4
    assert result.pending_events == expected_cursor - 4
    assert Store.get_projection_cursor(:trace_summary, tenant_id: tenant_id) == 4

    error =
      assert_raise Error, fn ->
        Projector.get_trace_summary(@dealdesk["trace_id"], tenant_id: tenant_id)
      end

    assert error.code == :projection_out_of_date

    health = Projector.projection_health(tenant_id: tenant_id)

    assert health.event_log_last_seq == expected_cursor

    trace_summary_status =
      Enum.find(health.projections, &(&1.projection_name == :trace_summary))

    assert trace_summary_status.last_log_seq == 4
    assert trace_summary_status.pending_events == expected_cursor - 4
    assert trace_summary_status.is_stale == true
    assert is_binary(health.full_digest)

    assert {:ok, resumed} = Engine.catch_up(:trace_summary, tenant_id: tenant_id, batch_size: 2)
    assert resumed.last_log_seq == expected_cursor

    assert Projector.get_trace_summary(@dealdesk["trace_id"], tenant_id: tenant_id).trace_id ==
             @dealdesk["trace_id"]
  end

  test "replay coordinator rebuilds all projections and persists run status" do
    tenant_id = "projector:rebuild-all"
    expected_cursor = @dealdesk["projection_snapshot"]["projection_cursor"]

    append_scenario!(@dealdesk, tenant_id)

    assert {:ok, run} = Projector.rebuild(:all, tenant_id: tenant_id, batch_size: 2)

    completed_run =
      wait_until(fn ->
        case Projector.replay_status(run["job_id"]) do
          %{"status" => "completed"} = status -> status
          _ -> nil
        end
      end)

    assert completed_run["projection_name"] == "all"
    assert completed_run["last_log_seq"] == expected_cursor
    assert completed_run["processed_events"] == @dealdesk["event_count"] * 3
    assert Projector.runtime_snapshot().active_replay_jobs == 0
  end

  test "projection workers record non-recoverable failures for operator inspection" do
    tenant_id = "projector:failure"

    append_events!(
      tenant_id,
      [
        trace_started_event("failure-trace"),
        policy_event("failure-trace", 1)
      ]
    )

    corrupt_payload_hash!(tenant_id, "failure-trace-policy_evaluated-1")

    assert {:ok, pid} = Projector.ensure_worker_started(tenant_id, :precedent_index)

    on_exit(fn ->
      if Process.alive?(pid) do
        DynamicSupervisor.terminate_child(DecisionGraph.Projector.WorkerSupervisor, pid)
      end
    end)

    failed_state =
      wait_until(fn ->
        state = Projector.worker_status(tenant_id, :precedent_index)
        if state.status == :failed, do: state
      end)

    assert failed_state.last_error.code == :conflict

    [failure | _rest] = Engine.list_failures(tenant_id: tenant_id)

    assert failure["projection_name"] == "precedent_index"
    assert failure["error_code"] == "conflict"
    assert failure["recoverable"] == false
    assert failure["status"] == "open"
    assert failure["event_id"] == "failure-trace-policy_evaluated-1"
    assert failure["trace_id"] == "failure-trace"
  end

  test "projection workers reload the durable cursor after restart and resume catch-up" do
    tenant_id = "projector:worker-restart"
    trace_id = "restart-trace"

    append_events!(tenant_id, [trace_started_event(trace_id)])

    assert {:ok, pid} = Projector.ensure_worker_started(tenant_id, :trace_summary)

    synced_state =
      wait_until(fn ->
        state = Projector.worker_status(tenant_id, :trace_summary)
        if state.cursor == 1 and state.sync_count > 0, do: state
      end)

    assert synced_state.status == :idle
    assert Store.get_projection_cursor(:trace_summary, tenant_id: tenant_id) == 1

    append_events!(tenant_id, [trace_finished_event(trace_id, 1)])

    :ok = DynamicSupervisor.terminate_child(DecisionGraph.Projector.WorkerSupervisor, pid)

    assert {:ok, restarted_pid} = Projector.ensure_worker_started(tenant_id, :trace_summary)

    on_exit(fn ->
      if Process.alive?(restarted_pid) do
        DynamicSupervisor.terminate_child(DecisionGraph.Projector.WorkerSupervisor, restarted_pid)
      end
    end)

    restarted_state =
      wait_until(fn ->
        state = Projector.worker_status(tenant_id, :trace_summary)
        if state.sync_count > 0 and state.cursor >= 1, do: state
      end)

    assert restarted_state.status == :idle
    assert restarted_state.cursor >= 1

    resumed_state =
      wait_until(fn ->
        state = Projector.worker_status(tenant_id, :trace_summary)
        if state.cursor == 2 and state.sync_count > 0, do: state
      end)

    assert resumed_state.status == :idle
    assert Store.get_projection_cursor(:trace_summary, tenant_id: tenant_id) == 2

    assert Projector.get_trace_summary(trace_id, tenant_id: tenant_id).outcome == "success"
  end

  test "trace-centered context subgraph returns the connected projection slice" do
    tenant_id = "projector:graph-query"

    append_scenario!(@dealdesk, tenant_id)

    assert {:ok, _results} = Engine.rebuild_all(tenant_id: tenant_id, batch_size: 2)

    context =
      Projector.get_context_subgraph(
        %NodeRef{node_type: "trace", node_id: @dealdesk["trace_id"]},
        tenant_id: tenant_id,
        filter: %GraphFilter{max_depth: 3, max_nodes: 100, max_edges: 100}
      )

    node_ids = Enum.map(context.nodes, & &1.node_id)

    cited_trace_id =
      @dealdesk["events"]
      |> Enum.find(&(&1["event_type"] == "PrecedentCited"))
      |> Map.fetch!("payload")
      |> Map.fetch!("cited_trace_id")

    trace_started_actor_id =
      @dealdesk["events"]
      |> Enum.find(&(&1["event_type"] == "TraceStarted"))
      |> Map.fetch!("actor")
      |> then(fn actor -> "#{actor["actor_type"]}:#{actor["actor_id"]}" end)

    assert context.truncated == false
    assert length(context.edges) == 8
    assert length(context.nodes) == 9
    assert "trace:#{@dealdesk["trace_id"]}" in node_ids
    assert "trace:#{cited_trace_id}" in node_ids
    refute "actor:#{trace_started_actor_id}" in node_ids

    assert SQL.query_one!(
             "SELECT COUNT(*) AS count FROM dg_cg_nodes WHERE tenant_id = $1",
             [tenant_id]
           )["count"] == 10
  end

  defp append_scenario!(scenario, tenant_id) do
    Enum.each(scenario["events"], fn attrs ->
      attrs
      |> EventEnvelope.new()
      |> Store.append_event(tenant_id: tenant_id)
    end)
  end

  defp append_events!(tenant_id, events) do
    Enum.each(events, &Store.append_event(&1, tenant_id: tenant_id))
  end

  defp trace_started_event(trace_id) do
    EventEnvelope.new(%{
      actor: %{actor_id: "projector-test", actor_type: "agent"},
      event_id: "#{trace_id}-trace_started-0",
      event_type: "TraceStarted",
      idempotency_key: "start:#{trace_id}",
      occurred_at: "2025-12-31T15:00:00Z",
      payload: %{
        "primary_entity" => %{
          "entity_id" => "entity:#{trace_id}",
          "entity_type" => "account",
          "system" => "crm"
        },
        "title" => "Failure trace #{trace_id}",
        "workflow" => "phase4_failure_test"
      },
      source: %{producer_id: "projector-test", subsystem: "phase4", system: "test"},
      trace_id: trace_id,
      trace_seq: 0
    })
  end

  defp policy_event(trace_id, trace_seq) do
    EventEnvelope.new(%{
      actor: %{actor_id: "projector-test", actor_type: "agent"},
      causation_event_id: "#{trace_id}-trace_started-0",
      event_id: "#{trace_id}-policy_evaluated-#{trace_seq}",
      event_type: "PolicyEvaluated",
      idempotency_key: "policy:#{trace_id}:#{trace_seq}",
      occurred_at: "2025-12-31T15:00:01Z",
      payload: %{
        "decision" => "allow",
        "inputs" => [],
        "policy" => %{"policy_id" => "broken_policy", "policy_version" => "1.0"},
        "violations" => []
      },
      source: %{producer_id: "projector-test", subsystem: "phase4", system: "test"},
      trace_id: trace_id,
      trace_seq: trace_seq
    })
  end

  defp trace_finished_event(trace_id, trace_seq) do
    EventEnvelope.new(%{
      actor: %{actor_id: "projector-test", actor_type: "agent"},
      causation_event_id: "#{trace_id}-trace_started-0",
      event_id: "#{trace_id}-trace_finished-#{trace_seq}",
      event_type: "TraceFinished",
      idempotency_key: "finish:#{trace_id}",
      occurred_at: "2025-12-31T15:00:02Z",
      payload: %{
        "outcome" => "success",
        "summary" => "Finished #{trace_id}"
      },
      source: %{producer_id: "projector-test", subsystem: "phase4", system: "test"},
      trace_id: trace_id,
      trace_seq: trace_seq
    })
  end

  defp corrupt_payload_hash!(tenant_id, event_id) do
    SQL.execute!(
      """
      UPDATE dg_event_log
      SET payload_hash = $3
      WHERE tenant_id = $1 AND event_id = $2
      """,
      [tenant_id, event_id, "corrupted-payload-hash"]
    )
  end

  defp wait_until(fun, attempts \\ 100)

  defp wait_until(fun, attempts) when attempts > 0 do
    case fun.() do
      nil ->
        Process.sleep(20)
        wait_until(fun, attempts - 1)

      result ->
        result
    end
  end

  defp wait_until(_fun, 0) do
    flunk("timed out waiting for asynchronous projector state")
  end
end
