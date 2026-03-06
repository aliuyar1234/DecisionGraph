defmodule DecisionGraph.Store.Application do
  @moduledoc "Supervises the repo only when the environment requests it."

  use Application

  @impl true
  def start(_type, _args) do
    children =
      if Application.get_env(:dg_store, :start_repo, false) do
        [DecisionGraph.Store.Repo]
      else
        []
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: DecisionGraph.Store.Supervisor)
  end
end
