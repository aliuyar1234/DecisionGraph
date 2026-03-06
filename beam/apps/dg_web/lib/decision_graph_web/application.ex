defmodule DecisionGraphWeb.Application do
  @moduledoc "Phoenix delivery shell for the Phase 2 BEAM bootstrap."
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: DecisionGraphWeb.PubSub},
      DecisionGraphWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: DecisionGraphWeb.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    DecisionGraphWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
