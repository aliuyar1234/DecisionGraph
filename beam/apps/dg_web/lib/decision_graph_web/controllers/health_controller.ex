defmodule DecisionGraphWeb.HealthController do
  use DecisionGraphWeb, :controller

  def show(conn, _params) do
    json(conn, DecisionGraph.Api.bootstrap_snapshot())
  end
end
