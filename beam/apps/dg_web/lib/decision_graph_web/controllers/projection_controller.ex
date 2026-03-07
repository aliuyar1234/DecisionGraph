defmodule DecisionGraphWeb.ProjectionController do
  use DecisionGraphWeb, :controller

  alias DecisionGraph.Api
  alias DecisionGraphWeb.ApiResponder

  def show(conn, _params) do
    case Api.service(:admin).projection_health(tenant_id: conn.assigns.api_tenant_id) do
      {:ok, result} -> ApiResponder.render_data(conn, 200, result)
      {:error, error} -> ApiResponder.render_error(conn, error)
    end
  end
end
