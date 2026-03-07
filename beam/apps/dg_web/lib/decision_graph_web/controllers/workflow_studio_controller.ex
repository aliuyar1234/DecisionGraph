defmodule DecisionGraphWeb.WorkflowStudioController do
  use DecisionGraphWeb, :controller

  alias DecisionGraph.Api
  alias DecisionGraphWeb.ApiResponder

  def index(conn, _params) do
    case Api.service(:workflow_studio).list_templates(tenant_id: conn.assigns.api_tenant_id) do
      {:ok, result} -> ApiResponder.render_data(conn, 200, %{templates: result})
      {:error, error} -> ApiResponder.render_error(conn, error)
    end
  end

  def show(conn, %{"trace_id" => trace_id} = params) do
    params = Map.delete(params, "trace_id")

    case Api.service(:workflow_studio).overview(trace_id, params, workflow_opts(conn)) do
      {:ok, result} -> ApiResponder.render_data(conn, 200, result)
      {:error, error} -> ApiResponder.render_error(conn, error)
    end
  end

  def create_review(conn, %{"trace_id" => trace_id} = params) do
    params = Map.delete(params, "trace_id")

    case Api.service(:workflow_studio).start_review(trace_id, params, workflow_opts(conn)) do
      {:ok, result} -> ApiResponder.render_data(conn, 201, result)
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
