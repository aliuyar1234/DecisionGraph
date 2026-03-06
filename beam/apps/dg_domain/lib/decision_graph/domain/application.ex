defmodule DecisionGraph.Domain.Application do
  @moduledoc "Supervision root for the domain boundary."

  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link([], strategy: :one_for_one, name: DecisionGraph.Domain.Supervisor)
  end
end
