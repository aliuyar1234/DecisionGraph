defmodule DecisionGraph.Observability.RequestContextTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias DecisionGraph.Observability.Plugs.RequestContext

  test "injects request metadata and response header" do
    conn =
      :get
      |> conn("/")
      |> put_req_header("x-trace-id", "trace-123")
      |> RequestContext.call([])

    assert get_resp_header(conn, "x-request-id") != []
    assert conn.assigns.runtime_context.trace_id == "trace-123"
  end
end
