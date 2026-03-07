defmodule DecisionGraphWeb.ApiResponder do
  @moduledoc false

  import Phoenix.Controller, only: [json: 2]
  import Plug.Conn

  alias DecisionGraph.Api.HttpError
  alias DecisionGraph.Api.Serialization

  @spec render_data(Plug.Conn.t(), integer(), term()) :: Plug.Conn.t()
  def render_data(conn, status, data) do
    conn
    |> put_status(status)
    |> json(%{
      data: Serialization.serialize(data),
      request_id: request_id(conn)
    })
  end

  @spec render_error(Plug.Conn.t(), HttpError.t()) :: Plug.Conn.t()
  def render_error(conn, %HttpError{} = error) do
    conn
    |> put_status(error.status)
    |> json(%{
      error: %{
        code: error.code,
        details: Serialization.serialize(error.details),
        message: error.message
      },
      request_id: request_id(conn)
    })
  end

  defp request_id(conn) do
    conn.assigns[:runtime_context]
    |> case do
      %{request_id: request_id} -> request_id
      _ -> conn |> get_resp_header("x-request-id") |> List.first()
    end
  end
end
