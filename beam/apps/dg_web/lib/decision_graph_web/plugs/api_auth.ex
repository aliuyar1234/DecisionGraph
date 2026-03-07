defmodule DecisionGraphWeb.Plugs.ApiAuth do
  @moduledoc false

  import Plug.Conn

  alias DecisionGraph.Api.Auth
  alias DecisionGraphWeb.ApiResponder

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, opts) do
    allowed_roles = Keyword.get(opts, :roles, [])
    tenant_id = header(conn, "x-tenant-id")
    authorization = header(conn, "authorization")

    case Auth.authenticate(authorization, tenant_id, allowed_roles) do
      {:ok, account} ->
        conn
        |> assign(:api_service_account, account)
        |> assign(:api_tenant_id, tenant_id)

      {:error, error} ->
        conn
        |> ApiResponder.render_error(error)
        |> halt()
    end
  end

  defp header(conn, name) do
    conn
    |> get_req_header(name)
    |> List.first()
  end
end
