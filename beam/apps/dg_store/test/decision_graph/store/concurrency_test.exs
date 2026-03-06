defmodule DecisionGraph.StoreConcurrencyTest do
  use DecisionGraph.Store.DataCase, async: false

  alias DecisionGraph.Error

  test "concurrent idempotent retries return the same stored event" do
    envelope = EventFactory.trace_started("trace-concurrent-idem")

    results =
      1..6
      |> Task.async_stream(
        fn _ -> Store.append_event(envelope) end,
        max_concurrency: 6,
        ordered: false,
        timeout: 15_000
      )
      |> Enum.map(fn {:ok, stored_event} -> stored_event end)

    assert Enum.uniq_by(results, & &1.log_seq) |> length() == 1
    assert Store.list_events() |> length() == 1
  end

  test "competing same-seq appends leave the trace in a valid state" do
    trace_id = "trace-concurrent-seq"
    Store.append_event(EventFactory.trace_started(trace_id))

    contenders = [
      EventFactory.input_observed(trace_id, 1, %{
        event_id: "contender-input",
        idempotency_key: "contender-input"
      }),
      EventFactory.trace_finished(trace_id, 1, %{
        event_id: "contender-finish",
        idempotency_key: "contender-finish"
      })
    ]

    results =
      contenders
      |> Task.async_stream(
        fn envelope ->
          try do
            {:ok, Store.append_event(envelope)}
          rescue
            error in Error -> {:error, error.code}
          end
        end,
        max_concurrency: 2,
        ordered: false,
        timeout: 15_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(results, fn result -> match?({:ok, _}, result) end) == 1
    assert Enum.count(results, fn result -> match?({:error, _}, result) end) == 1

    trace_events = Store.get_trace_events(trace_id)

    assert Enum.map(trace_events, & &1.trace_seq) == Enum.to_list(0..(length(trace_events) - 1))
    assert length(trace_events) == 2
  end

  test "concurrent appends across tenants and traces do not interfere" do
    envelopes = [
      {"tenant-a", EventFactory.trace_started("shared-trace")},
      {"tenant-b", EventFactory.trace_started("shared-trace", %{event_id: "tenant-b-start"})},
      {"tenant-a", EventFactory.trace_started("other-trace", %{event_id: "tenant-a-other"})},
      {"tenant-b", EventFactory.trace_started("another-trace", %{event_id: "tenant-b-other"})}
    ]

    results =
      envelopes
      |> Task.async_stream(
        fn {tenant_id, envelope} -> Store.append_event(envelope, tenant_id: tenant_id) end,
        max_concurrency: 4,
        ordered: false,
        timeout: 15_000
      )
      |> Enum.map(fn {:ok, stored_event} -> stored_event end)

    assert Enum.sort(Enum.map(results, & &1.log_seq)) == [1, 2, 3, 4]
    assert Store.get_next_trace_seq("shared-trace", tenant_id: "tenant-a") == 1
    assert Store.get_next_trace_seq("shared-trace", tenant_id: "tenant-b") == 1
    assert length(Store.list_events(tenant_id: "tenant-a")) == 2
    assert length(Store.list_events(tenant_id: "tenant-b")) == 2
  end
end
