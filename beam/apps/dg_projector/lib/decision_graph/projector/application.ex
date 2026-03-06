defmodule DecisionGraph.Projector.Application do
  @moduledoc "Supervises registries and projector worker lifecycles."

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: DecisionGraph.Projector.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: DecisionGraph.Projector.WorkerSupervisor},
      {Task.Supervisor, name: DecisionGraph.Projector.ReplaySupervisor}
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: DecisionGraph.Projector.Supervisor
    )
  end
end
