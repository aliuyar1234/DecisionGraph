defmodule DecisionGraphWeb.BootstrapLiveTest do
  use DecisionGraphWeb.ConnCase, async: true

  test "renders bootstrap studio with current auth snapshot", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/bootstrap")

    assert html =~ "Bootstrap Studio"
    assert html =~ "Current Runtime Auth State"
    assert html =~ "Fresh Bootstrap Preview"
    assert html =~ "Token Rotation Preview"
    assert html =~ "reader-test"
    assert html =~ "admin-test"
  end

  test "updates the bootstrap preview when form inputs change", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/bootstrap")

    html =
      view
      |> form("form[phx-change=\"bootstrap_form_change\"]",
        bootstrap: %{
          account_prefix: "staging",
          include_release_demo: "true",
          tenant_id: "tenant-b"
        }
      )
      |> render_change()

    assert html =~ "reader-staging"
    assert html =~ "admin-staging"
    assert html =~ "release-demo"
    assert html =~ "tenant-b"
  end

  test "updates the rotation preview for the selected account", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/bootstrap")

    html =
      view
      |> form("form[phx-change=\"rotation_form_change\"]",
        rotation: %{
          account_id: "reader-test"
        }
      )
      |> render_change()

    assert html =~ "&quot;account_id&quot;: &quot;reader-test&quot;"
    assert html =~ "&quot;tokens&quot;: ["
    assert html =~ "overlap window"
  end
end
