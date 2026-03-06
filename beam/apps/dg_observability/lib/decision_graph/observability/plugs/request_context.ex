defmodule DecisionGraph.Observability.Plugs.RequestContext do
  @moduledoc """
  Establishes request, trace, and tenant context for logs and downstream code.
  """

  import Plug.Conn

  alias DecisionGraph.Domain.RuntimeContext
  alias DecisionGraph.Observability.LogContext

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    context =
      RuntimeContext.new(
        deployment_env: Application.get_env(:dg_api, :deployment_env, "dev"),
        request_id: header(conn, "x-request-id") || generate_request_id(),
        tenant_id: header(conn, "x-tenant-id"),
        trace_id: header(conn, "x-trace-id")
      )

    LogContext.put(context)

    conn
    |> assign(:runtime_context, context)
    |> put_resp_header("x-request-id", context.request_id)
    |> register_before_send(fn final_conn ->
      LogContext.clear()
      final_conn
    end)
  end

  defp header(conn, name) do
    conn
    |> get_req_header(name)
    |> List.first()
    |> case do
      nil -> nil
      value -> String.trim(value)
    end
  end

  defp generate_request_id do
    Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
  end
end
