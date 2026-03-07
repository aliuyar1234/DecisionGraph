defmodule DecisionGraphWeb.TraceController do
  use DecisionGraphWeb, :controller

  alias DecisionGraph.Api
  alias DecisionGraphWeb.ApiResponder

  def show(conn, %{"trace_id" => trace_id}) do
    case Api.service(:traces).get_trace(trace_id, tenant_id: conn.assigns.api_tenant_id) do
      {:ok, result} -> ApiResponder.render_data(conn, 200, result)
      {:error, error} -> ApiResponder.render_error(conn, error)
    end
  end
end
