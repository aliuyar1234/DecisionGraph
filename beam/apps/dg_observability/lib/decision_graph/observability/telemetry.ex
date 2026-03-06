defmodule DecisionGraph.Observability.Telemetry do
  @moduledoc "Metric definitions for the bootstrap runtime."

  import Telemetry.Metrics

  @spec metrics() :: [Telemetry.Metrics.t()]
  def metrics do
    [
      summary("decision_graph.vm.memory.total"),
      counter("decision_graph.projector.worker.started.count"),
      counter("decision_graph.projector.worker.sync.count")
    ]
  end
end
