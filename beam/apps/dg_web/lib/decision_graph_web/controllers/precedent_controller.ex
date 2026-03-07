defmodule DecisionGraphWeb.PrecedentController do
  use DecisionGraphWeb, :controller

  alias DecisionGraph.Api
  alias DecisionGraphWeb.ApiResponder

  def index(conn, params) do
    case Api.service(:precedents).find_precedents(params, tenant_id: conn.assigns.api_tenant_id) do
      {:ok, results} -> ApiResponder.render_data(conn, 200, %{precedents: results})
      {:error, error} -> ApiResponder.render_error(conn, error)
    end
  end
end
