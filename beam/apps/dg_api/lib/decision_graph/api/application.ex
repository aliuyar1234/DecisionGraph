defmodule DecisionGraph.Api.Application do
  @moduledoc "API boundary supervisor for future service-facing work."

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: DecisionGraph.Api.TaskSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: DecisionGraph.Api.Supervisor)
  end
end
