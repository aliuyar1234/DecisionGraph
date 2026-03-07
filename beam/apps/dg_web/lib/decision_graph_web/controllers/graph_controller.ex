defmodule DecisionGraphWeb.GraphController do
  use DecisionGraphWeb, :controller

  alias DecisionGraph.Api
  alias DecisionGraphWeb.ApiResponder

  def context(conn, params) do
    case Api.service(:graph).get_context_subgraph(params, tenant_id: conn.assigns.api_tenant_id) do
      {:ok, result} -> ApiResponder.render_data(conn, 200, result)
      {:error, error} -> ApiResponder.render_error(conn, error)
    end
  end

  def edges(conn, params) do
    case Api.service(:graph).list_node_edges(params, tenant_id: conn.assigns.api_tenant_id) do
      {:ok, result} -> ApiResponder.render_data(conn, 200, result)
      {:error, error} -> ApiResponder.render_error(conn, error)
    end
  end
end
