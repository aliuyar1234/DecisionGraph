defmodule DecisionGraph.Observability.Telemetry do
  @moduledoc "Metric definitions for the bootstrap runtime."

  import Telemetry.Metrics

  @spec metrics() :: [Telemetry.Metrics.t()]
  def metrics do
    [
      summary("decision_graph.vm.memory.total"),
      counter("decision_graph.store.append.stop.count"),
      summary("decision_graph.store.append.stop.duration"),
      counter("decision_graph.store.append.exception.count"),
      counter("decision_graph.store.idempotency.reuse.count"),
      counter("decision_graph.store.read_batch.stop.count"),
      summary("decision_graph.store.read_batch.stop.events"),
      counter("decision_graph.projector.worker.started.count"),
      counter("decision_graph.projector.worker.sync.count")
    ]
  end
end
