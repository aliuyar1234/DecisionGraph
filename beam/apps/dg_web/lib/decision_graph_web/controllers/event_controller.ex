defmodule DecisionGraphWeb.EventController do
  use DecisionGraphWeb, :controller

  alias DecisionGraph.Api
  alias DecisionGraphWeb.ApiResponder

  def create(conn, params) do
    case Api.service(:events).append_event(
           params,
           tenant_id: conn.assigns.api_tenant_id,
           request_id: request_id(conn)
         ) do
      {:ok, result} -> ApiResponder.render_data(conn, 201, result)
      {:error, error} -> ApiResponder.render_error(conn, error)
    end
  end

  defp request_id(%{assigns: %{runtime_context: %{request_id: request_id}}}), do: request_id
  defp request_id(_conn), do: nil
end
