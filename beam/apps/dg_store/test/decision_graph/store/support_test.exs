defmodule DecisionGraph.Store.SupportTest do
  use ExUnit.Case, async: true

  alias DecisionGraph.Error
  alias DecisionGraph.Store.Support

  test "collect_clauses numbers placeholders deterministically" do
    assert Support.collect_clauses(
             [
               {"tenant_id = ?", "tenant-a"},
               nil,
               {"trace_id = ?", "trace-1"}
             ],
             "TRUE"
           ) == {["tenant_id = $1", "trace_id = $2"], ["tenant-a", "trace-1"]}
  end

  test "normalize_projection_name accepts atoms and binaries from the configured list" do
    projections = [:context_graph, :trace_summary]

    assert Support.normalize_projection_name(:context_graph, projections) == "context_graph"
    assert Support.normalize_projection_name("trace_summary", projections) == "trace_summary"

    assert_raise Error, fn ->
      Support.normalize_projection_name("precedent_index", projections)
    end
  end

  test "row_to_stored_event rebuilds stored events from SQL rows" do
    event =
      Support.row_to_stored_event(%{
        "actor_id" => "agent-1",
        "actor_type" => "agent",
        "causation_event_id" => "evt-0",
        "correlation_id" => "corr-1",
        "event_id" => "evt-1",
        "event_type" => "TraceStarted",
        "idempotency_key" => "trace:evt-1",
        "log_seq" => 5,
        "occurred_at" => "2026-03-09T10:00:00Z",
        "payload_hash" => "hash-1",
        "payload_json" => ~s({"workflow":"renewal"}),
        "producer_id" => "producer-1",
        "recorded_at" => "2026-03-09T10:00:01Z",
        "schema_version" => 1,
        "source_subsystem" => "seed",
        "source_system" => "decisiongraph",
        "tags_json" => ~s(["phase10"]),
        "tenant_id" => "tenant-a",
        "trace_id" => "trace-1",
        "trace_seq" => 0
      })

    assert event.trace_id == "trace-1"
    assert event.source.producer_id == "producer-1"
    assert event.payload == %{"workflow" => "renewal"}
    assert event.tags == ["phase10"]
  end
end
