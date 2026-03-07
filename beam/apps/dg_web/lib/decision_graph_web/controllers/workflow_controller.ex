defmodule DecisionGraphWeb.WorkflowController do
  use DecisionGraphWeb, :controller

  alias DecisionGraph.Api
  alias DecisionGraphWeb.ApiResponder

  def index(conn, params) do
    case Api.service(:workflows).list_inbox(params, tenant_id: conn.assigns.api_tenant_id) do
      {:ok, result} -> ApiResponder.render_data(conn, 200, result)
      {:error, error} -> ApiResponder.render_error(conn, error)
    end
  end

  def show(conn, %{"workflow_id" => workflow_id}) do
    case Api.service(:workflows).get_workflow(workflow_id, tenant_id: conn.assigns.api_tenant_id) do
      {:ok, result} -> ApiResponder.render_data(conn, 200, result)
      {:error, error} -> ApiResponder.render_error(conn, error)
    end
  end

  def act(conn, %{"workflow_id" => workflow_id} = params) do
    case Api.service(:workflows).act_on_workflow(
           workflow_id,
           Map.delete(params, "workflow_id"),
           workflow_opts(conn)
         ) do
      {:ok, result} -> ApiResponder.render_data(conn, 200, result)
      {:error, error} -> ApiResponder.render_error(conn, error)
    end
  end

  def export(conn, %{"workflow_id" => workflow_id}) do
    case Api.service(:workflows).export_workflow(workflow_id, workflow_opts(conn)) do
      {:ok, result} -> ApiResponder.render_data(conn, 200, result)
      {:error, error} -> ApiResponder.render_error(conn, error)
    end
  end

  defp workflow_opts(conn) do
    [
      actor: conn.assigns[:api_service_account],
      request_id: request_id(conn),
      tenant_id: conn.assigns.api_tenant_id
    ]
  end

  defp request_id(%{assigns: %{runtime_context: %{request_id: request_id}}}), do: request_id
  defp request_id(_conn), do: nil
end
