defmodule DecisionGraphWeb.DashboardLiveTest do
  use DecisionGraphWeb.ConnCase, async: true

  test "renders the bootstrap dashboard", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    assert html =~ "BEAM runtime shell is online."
    assert html =~ "DecisionGraph Phase 2"
  end
end
