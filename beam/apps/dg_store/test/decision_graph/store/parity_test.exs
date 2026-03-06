defmodule DecisionGraph.StoreParityTest do
  use DecisionGraph.Store.DataCase, async: false

  alias DecisionGraph.Domain.EventEnvelope
  alias DecisionGraph.Error

  @fixture_bundle_path Path.expand(
                         "../../../../../../tests/golden/reference_fixture_bundle.json",
                         __DIR__
                       )
  @bundle File.read!(@fixture_bundle_path) |> Jason.decode!()
  @scenarios @bundle["scenarios"]

  for scenario <- @scenarios do
    @scenario scenario
    @scenario_name scenario["scenario"]

    test "replays reference fixture bundle scenario #{@scenario_name}" do
      tenant_id = "parity:" <> @scenario_name

      stored_events =
        Enum.map(@scenario["events"], fn event ->
          event
          |> EventEnvelope.new()
          |> Store.append_event(tenant_id: tenant_id)
        end)

      trace_events = Store.get_trace_events(@scenario["trace_id"], tenant_id: tenant_id)
      listed_events = Store.list_events(tenant_id: tenant_id)

      assert length(stored_events) == @scenario["event_count"]
      assert Enum.map(trace_events, & &1.event_type) == @scenario["event_type_sequence"]

      assert Enum.map(trace_events, & &1.event_id) ==
               Enum.map(@scenario["events"], & &1["event_id"])

      assert Enum.map(listed_events, & &1.log_seq) == Enum.to_list(1..@scenario["event_count"])

      assert Store.get_next_trace_seq(@scenario["trace_id"], tenant_id: tenant_id) ==
               @scenario["event_count"]

      assert Store.iter_event_batches(tenant_id: tenant_id, batch_size: 3)
             |> Enum.flat_map(& &1)
             |> Enum.map(& &1.event_id) == Enum.map(@scenario["events"], & &1["event_id"])

      if List.last(@scenario["event_type_sequence"]) == "TraceFinished" do
        assert Store.is_trace_finished(@scenario["trace_id"], tenant_id: tenant_id)
      end
    end
  end

  test "preserves idempotent reuse semantics when trace_seq drifts" do
    original = EventFactory.trace_started("parity-idempotent")
    stored = Store.append_event(original, tenant_id: "parity:idempotent")

    retried =
      original
      |> Map.from_struct()
      |> Map.merge(%{"event_id" => "parity-retry", "trace_seq" => 99})
      |> EventEnvelope.new()
      |> Store.append_event(tenant_id: "parity:idempotent")

    assert retried.log_seq == stored.log_seq
    assert retried.event_id == stored.event_id
    assert Store.list_events(tenant_id: "parity:idempotent") |> length() == 1
  end

  test "rejects invalid trace sequencing with the reference error category" do
    tenant_id = "parity:sequence"
    trace_id = "parity-sequence-trace"

    Store.append_event(EventFactory.trace_started(trace_id), tenant_id: tenant_id)

    error =
      assert_raise Error, fn ->
        Store.append_event(EventFactory.input_observed(trace_id, 2), tenant_id: tenant_id)
      end

    assert error.code == :event_sequence_invalid
  end

  test "rejects writes after TraceFinished with the reference conflict category" do
    tenant_id = "parity:finished"
    trace_id = "parity-finished-trace"

    Store.append_event(EventFactory.trace_started(trace_id), tenant_id: tenant_id)
    Store.append_event(EventFactory.trace_finished(trace_id, 1), tenant_id: tenant_id)

    error =
      assert_raise Error, fn ->
        Store.append_event(EventFactory.input_observed(trace_id, 2), tenant_id: tenant_id)
      end

    assert error.code == :conflict
  end
end
