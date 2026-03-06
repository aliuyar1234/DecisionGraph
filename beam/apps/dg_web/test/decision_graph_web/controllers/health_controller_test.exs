defmodule DecisionGraphWeb.HealthControllerTest do
  use DecisionGraphWeb.ConnCase, async: true

  test "returns the bootstrap snapshot", %{conn: conn} do
    conn = get(conn, "/api/healthz")

    assert %{
             "deployment_env" => "test",
             "projector" => %{"partition_count" => partition_count}
           } = json_response(conn, 200)

    assert partition_count > 0
    assert get_resp_header(conn, "x-request-id") != []
  end
end
