defmodule DecisionGraphWeb.DashboardLiveTest do
  use DecisionGraphWeb.ConnCase, async: true

  setup do
    previous_services = Application.get_env(:dg_api, :services)

    Application.put_env(:dg_api, :services, %{
      admin: DecisionGraphWeb.Test.AdminServiceFake,
      graph: DecisionGraphWeb.Test.GraphServiceFake,
      precedents: DecisionGraphWeb.Test.PrecedentServiceFake,
      traces: DecisionGraphWeb.Test.TraceServiceFake,
      workflows: DecisionGraphWeb.Test.WorkflowServiceFake,
      workflow_studio: DecisionGraphWeb.Test.WorkflowStudioServiceFake
    })

    on_exit(fn ->
      if previous_services,
        do: Application.put_env(:dg_api, :services, previous_services),
        else: Application.delete_env(:dg_api, :services)
    end)

    :ok
  end

  test "renders the operator console shell with projection health and recent traces", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, "/?tenant=tenant-a")

    assert html =~ "Operator Console"
    assert html =~ "Projection Health Dashboard"
    assert html =~ "Workflow Inbox"
    assert html =~ "Workflow Detail"
    assert html =~ "Workflow Studio and Incident Review"
    assert html =~ "Context Graph Visualizer"
    assert html =~ "Precedent Browser and Comparison"
    assert html =~ "Replay Console"
    assert html =~ "Live Event Stream"
    assert html =~ "Tenant Status"
    assert html =~ "Environment Status"
    assert html =~ "Recent Traces"
    assert html =~ "Escalated deal review"
    assert html =~ "trace_summary"
  end

  test "renders the trace explorer timeline and payload inspection for a selected trace", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, "/?tenant=tenant-a&trace_id=trace-123")

    assert html =~ "Trace Explorer"
    assert html =~ "Policy and Exception Review"
    assert html =~ "Escalated deal review"
    assert html =~ "trace-123:exception:ex-42"
    assert html =~ "PolicyEvaluated"
    assert html =~ "ApprovalRecorded"
    assert html =~ "Payload Inspection"
    assert html =~ "Within policy tolerance"
    assert html =~ "deal-42"
    assert html =~ "Approved enterprise renewal"
  end

  test "starts trace reviews from workflow studio", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/?tenant=tenant-a&trace_id=trace-123")

    html =
      view
      |> form("form[phx-submit=\"start_trace_review\"]",
        review: %{
          reason: "incident triage review requested",
          template_id: "incident_triage"
        }
      )
      |> render_submit()

    assert html =~ "Trace review started for trace-123"
  end

  test "queues replay requests from the console", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/?tenant=tenant-a&trace_id=trace-123")

    html =
      view
      |> form("form[phx-submit=\"start_replay\"]",
        replay: %{
          confirm_text: "CATCH_UP TRACE_SUMMARY",
          mode: "catch_up",
          projection: "trace_summary",
          reason: "verify runtime posture"
        }
      )
      |> render_submit()

    assert html =~ "Replay queued: job-1"
  end

  test "submits workflow actions from the console", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, "/?tenant=tenant-a&trace_id=trace-123&workflow_id=trace-123:exception:ex-42")

    html =
      view
      |> form("form[phx-submit=\"submit_workflow_action\"]",
        workflow: %{
          action: "approve",
          assigned_account_id: "",
          assigned_role: "",
          confirm_text: "",
          note: "approved in test",
          reason: "manual review complete"
        }
      )
      |> render_submit()

    assert html =~ "Workflow action recorded for trace-123:exception:ex-42"
  end
end
