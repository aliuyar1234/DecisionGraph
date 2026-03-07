defmodule DecisionGraphWeb.Plugs.RateLimit do
  @moduledoc false

  import Plug.Conn

  alias DecisionGraph.Api.RateLimiter
  alias DecisionGraphWeb.ApiResponder

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, opts) do
    scope = Keyword.fetch!(opts, :scope)
    account_id = service_account_id(conn) || remote_ip(conn)
    tenant_id = conn.assigns[:api_tenant_id] || "unknown"

    case RateLimiter.check(scope, "#{account_id}:#{tenant_id}") do
      :ok ->
        conn

      {:error, error} ->
        conn
        |> ApiResponder.render_error(error)
        |> halt()
    end
  end

  defp remote_ip(conn) do
    conn.remote_ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  defp service_account_id(%{assigns: %{api_service_account: %{account_id: account_id}}}),
    do: account_id

  defp service_account_id(_conn), do: nil
end
