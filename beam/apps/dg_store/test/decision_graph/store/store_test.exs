defmodule DecisionGraph.StoreTest do
  use DecisionGraph.Store.DataCase, async: false

  alias DecisionGraph.Error

  test "reports deployment snapshot with repo config" do
    snapshot = Store.deployment_snapshot()

    assert snapshot.database == "decisiongraph_beam_test"
    assert snapshot.maintenance_database == "postgres"
    assert "context_graph" in snapshot.projection_names
  end

  test "appends and reads events in deterministic order" do
    trace_id = "trace-001"

    Store.append_event(EventFactory.trace_started(trace_id))
    Store.append_event(EventFactory.input_observed(trace_id, 1))
    Store.append_event(EventFactory.trace_finished(trace_id, 2))

    trace_events = Store.get_trace_events(trace_id)
    log_events = Store.list_events(trace_id: trace_id)

    assert Enum.map(trace_events, & &1.trace_seq) == [0, 1, 2]

    assert Enum.map(trace_events, & &1.event_type) == [
             "TraceStarted",
             "InputObserved",
             "TraceFinished"
           ]

    assert Enum.map(log_events, & &1.log_seq) == [1, 2, 3]
    assert Store.get_last_log_seq() == 3
    assert Store.get_next_trace_seq(trace_id) == 3
    assert Store.is_trace_finished(trace_id)
  end

  test "idempotent retries return the existing event even if trace_seq drifts" do
    trace_id = "trace-idempotent"
    original = EventFactory.trace_started(trace_id)
    stored = Store.append_event(original)

    retry =
      EventFactory.trace_started(trace_id, %{
        event_id: "retry-event-id",
        trace_seq: 9
      })

    retried = Store.append_event(retry)

    assert retried.log_seq == stored.log_seq
    assert retried.event_id == stored.event_id
    assert length(Store.list_events(trace_id: trace_id)) == 1
  end

  test "raises idempotency conflict for payload mismatches" do
    trace_id = "trace-idem-payload"
    Store.append_event(EventFactory.trace_started(trace_id))

    conflict =
      EventFactory.trace_started(trace_id, %{
        event_id: "payload-conflict",
        payload: %{
          "primary_entity" => %{
            "entity_id" => "entity:other",
            "entity_type" => "account",
            "system" => "crm"
          },
          "title" => "Other title",
          "workflow" => "phase3_store"
        }
      })

    assert_raise Error, fn -> Store.append_event(conflict) end
  end

  test "raises idempotency conflict for metadata mismatches" do
    trace_id = "trace-idem-meta"
    Store.append_event(EventFactory.trace_started(trace_id))

    conflict =
      EventFactory.trace_started(trace_id, %{
        actor: %{
          actor_id: "other-actor",
          actor_type: "agent"
        },
        event_id: "meta-conflict"
      })

    assert_raise Error, fn -> Store.append_event(conflict) end
  end

  test "rejects non TraceStarted events at trace_seq zero" do
    assert_raise Error, fn ->
      Store.append_event(
        EventFactory.input_observed("trace-invalid-zero", 0, %{
          idempotency_key: "invalid-zero"
        })
      )
    end
  end

  test "rejects trace sequence gaps" do
    trace_id = "trace-gap"
    Store.append_event(EventFactory.trace_started(trace_id))

    assert_raise Error, fn ->
      Store.append_event(EventFactory.input_observed(trace_id, 2))
    end
  end

  test "rejects writes after TraceFinished" do
    trace_id = "trace-finished"
    Store.append_event(EventFactory.trace_started(trace_id))
    Store.append_event(EventFactory.trace_finished(trace_id, 1))

    assert_raise Error, fn ->
      Store.append_event(EventFactory.input_observed(trace_id, 2))
    end
  end

  test "filters list_events and get_trace_events" do
    trace_id = "trace-filters"

    Store.append_event(EventFactory.trace_started(trace_id))
    Store.append_event(EventFactory.input_observed(trace_id, 1))
    Store.append_event(EventFactory.policy_evaluated(trace_id, 2))
    Store.append_event(EventFactory.trace_finished(trace_id, 3))

    assert Enum.map(Store.list_events(event_type: "PolicyEvaluated"), & &1.event_type) == [
             "PolicyEvaluated"
           ]

    assert Enum.map(Store.list_events(since_log_seq: 1, until_log_seq: 3), & &1.log_seq) == [2, 3]

    assert Enum.map(
             Store.get_trace_events(trace_id, since_trace_seq: 1, limit: 2),
             & &1.trace_seq
           ) == [2, 3]
  end

  test "filters list_events by occurred_at window" do
    trace_id = "trace-time-window"

    Store.append_event(EventFactory.trace_started(trace_id))
    Store.append_event(EventFactory.input_observed(trace_id, 1))
    Store.append_event(EventFactory.policy_evaluated(trace_id, 2))
    Store.append_event(EventFactory.trace_finished(trace_id, 3))

    events =
      Store.list_events(
        since_occurred_at: "2025-12-31T12:00:00Z",
        until_occurred_at: "2025-12-31T12:00:02Z"
      )

    assert Enum.map(events, & &1.trace_seq) == [1, 2]
  end

  test "rejects invalid list_events bounds" do
    assert_raise Error, fn ->
      Store.list_events(since_log_seq: 10, until_log_seq: 5)
    end

    assert_raise Error, fn ->
      Store.list_events(
        since_occurred_at: "2025-12-31T12:00:03Z",
        until_occurred_at: "2025-12-31T12:00:02Z"
      )
    end
  end

  test "supports tenant-aware writes and reads" do
    trace_id = "shared-trace"

    Store.append_event(EventFactory.trace_started(trace_id), tenant_id: "tenant-a")

    Store.append_event(EventFactory.trace_started(trace_id, %{event_id: "tenant-b-start"}),
      tenant_id: "tenant-b"
    )

    assert length(Store.list_events()) == 2
    assert length(Store.list_events(tenant_id: "tenant-a")) == 1
    assert length(Store.list_events(tenant_id: "tenant-b")) == 1

    assert Store.get_trace_events(trace_id, tenant_id: "tenant-a")
           |> hd()
           |> Map.fetch!(:tenant_id) == "tenant-a"
  end

  test "projection cursors can be upserted and listed" do
    assert Store.get_projection_cursor(:trace_summary) == 0

    :ok = Store.put_projection_cursor(:trace_summary, 11)
    :ok = Store.put_projection_cursor("trace_summary", 12)

    assert Store.get_projection_cursor(:trace_summary) == 12

    assert Store.list_projection_cursors() == [
             %{
               "last_log_seq" => 12,
               "projection_name" => "trace_summary",
               "tenant_id" => "default",
               "updated_at" => Store.list_projection_cursors() |> hd() |> Map.fetch!("updated_at")
             }
           ]
  end

  test "clear resets stored events and log sequence" do
    trace_id = "trace-clear"
    Store.append_event(EventFactory.trace_started(trace_id))
    Store.append_event(EventFactory.trace_finished(trace_id, 1))

    assert Store.get_last_log_seq() == 2

    :ok = Store.clear()

    assert Store.list_events() == []
    assert Store.get_trace_events(trace_id) == []
    assert Store.get_last_log_seq() == 0
    assert Store.get_next_trace_seq(trace_id) == 0

    restarted = Store.append_event(EventFactory.trace_started("trace-clear-restarted"))
    assert restarted.log_seq == 1
  end

  test "migrations provision the expected phase 3 tables" do
    event_table = Repo.query!("SELECT to_regclass('public.dg_event_log')::text AS name").rows

    cursor_table =
      Repo.query!("SELECT to_regclass('public.dg_projection_cursors')::text AS name").rows

    assert event_table == [["dg_event_log"]]
    assert cursor_table == [["dg_projection_cursors"]]
  end

  property "iter_event_batches preserves global log ordering" do
    trace_a = "trace-batch-a"
    trace_b = "trace-batch-b"

    Store.append_event(EventFactory.trace_started(trace_a))
    Store.append_event(EventFactory.input_observed(trace_a, 1))
    Store.append_event(EventFactory.trace_started(trace_b, %{event_id: "trace-b-start"}))
    Store.append_event(EventFactory.input_observed(trace_b, 1, %{event_id: "trace-b-input"}))
    Store.append_event(EventFactory.trace_finished(trace_a, 2))

    ordered_ids = Store.list_events() |> Enum.map(& &1.event_id)

    check all(batch_size <- StreamData.integer(1..4)) do
      streamed_ids =
        Store.iter_event_batches(batch_size: batch_size)
        |> Enum.flat_map(& &1)
        |> Enum.map(& &1.event_id)

      assert streamed_ids == ordered_ids
    end
  end
end
