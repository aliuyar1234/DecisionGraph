defmodule DecisionGraphWeb.ReplayController do
  use DecisionGraphWeb, :controller

  alias DecisionGraph.Api
  alias DecisionGraphWeb.ApiResponder

  def create(conn, params) do
    case Api.service(:admin).start_replay(params, admin_opts(conn)) do
      {:ok, result} -> ApiResponder.render_data(conn, 202, %{run: result})
      {:error, error} -> ApiResponder.render_error(conn, error)
    end
  end

  def show(conn, %{"job_id" => job_id}) do
    case Api.service(:admin).replay_status(job_id, admin_opts(conn)) do
      {:ok, result} -> ApiResponder.render_data(conn, 200, %{run: result})
      {:error, error} -> ApiResponder.render_error(conn, error)
    end
  end

  def cancel(conn, %{"job_id" => job_id}) do
    case Api.service(:admin).cancel_replay(job_id, admin_opts(conn)) do
      {:ok, result} -> ApiResponder.render_data(conn, 200, %{run: result})
      {:error, error} -> ApiResponder.render_error(conn, error)
    end
  end

  defp admin_opts(conn) do
    [
      actor: conn.assigns.api_service_account,
      request_id: request_id(conn),
      tenant_id: conn.assigns.api_tenant_id
    ]
  end

  defp request_id(%{assigns: %{runtime_context: %{request_id: request_id}}}), do: request_id
  defp request_id(_conn), do: nil
end
