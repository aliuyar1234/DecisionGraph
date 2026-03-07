defmodule DecisionGraphWeb.ApiControllerTest do
  use DecisionGraphWeb.ConnCase, async: true

  setup do
    previous_services = Application.get_env(:dg_api, :services)
    previous_limits = Application.get_env(:dg_api, :rate_limits)

    Application.put_env(:dg_api, :services, %{
      admin: DecisionGraphWeb.Test.AdminServiceFake,
      events: DecisionGraphWeb.Test.EventServiceFake,
      graph: DecisionGraphWeb.Test.GraphServiceFake,
      precedents: DecisionGraphWeb.Test.PrecedentServiceFake,
      traces: DecisionGraphWeb.Test.TraceServiceFake,
      workflows: DecisionGraphWeb.Test.WorkflowServiceFake,
      workflow_studio: DecisionGraphWeb.Test.WorkflowStudioServiceFake
    })

    Application.put_env(:dg_api, :rate_limits, %{admin: 5, read: 5, write: 5})

    on_exit(fn ->
      if previous_services,
        do: Application.put_env(:dg_api, :services, previous_services),
        else: Application.delete_env(:dg_api, :services)

      if previous_limits,
        do: Application.put_env(:dg_api, :rate_limits, previous_limits),
        else: Application.delete_env(:dg_api, :rate_limits)
    end)

    :ok
  end

  test "rejects unauthenticated write requests", %{conn: conn} do
    conn =
      conn
      |> put_req_header("x-tenant-id", "tenant-a")
      |> post("/api/v1/events", %{})

    assert %{"error" => %{"code" => "unauthorized"}} = json_response(conn, 401)
  end

  test "appends an event through the authenticated ingestion endpoint", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer writer-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> post("/api/v1/events", %{
        "event_id" => "evt-1",
        "event_type" => "TraceStarted",
        "trace_id" => "trace-1"
      })

    assert %{
             "data" => %{
               "event" => %{"event_id" => "evt-1", "tenant_id" => "tenant-a"},
               "projection_sync_triggered" => true
             }
           } = json_response(conn, 201)
  end

  test "reads traces through the authenticated read endpoint", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer reader-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> get("/api/v1/traces/trace-1")

    assert %{"data" => %{"events" => events, "summary" => summary}} = json_response(conn, 200)

    assert Enum.at(events, 0)["event_id"] == "evt-1"
    assert Enum.at(events, 1)["event_type"] == "PolicyEvaluated"
    assert summary["trace_id"] == "trace-1"
    assert summary["tenant_id"] == "tenant-a"
    assert summary["workflow"] == "fake_workflow"
  end

  test "serves graph context and edge queries for authenticated readers", %{conn: conn} do
    context_conn =
      conn
      |> put_req_header("authorization", "Bearer reader-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> get("/api/v1/graph/context", %{"node_id" => "acct-1", "node_type" => "account"})

    assert %{"data" => %{"center" => %{"node_id" => "acct-1", "node_type" => "account"}}} =
             json_response(context_conn, 200)

    assert [%{"edge_id" => "edge-1"} | _rest] =
             get_in(json_response(context_conn, 200), ["data", "edges"])

    edges_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer reader-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> get("/api/v1/graph/edges", %{"node_id" => "acct-1", "node_type" => "account"})

    assert %{"data" => %{"edges" => [%{"edge_id" => "edge-1"}]}} = json_response(edges_conn, 200)
  end

  test "serves precedent searches for authenticated readers", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer reader-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> get("/api/v1/precedents", %{"entity_id" => "acct-1", "entity_type" => "account"})

    assert [%{"trace_id" => "precedent-trace-1"} | _rest] =
             get_in(json_response(conn, 200), ["data", "precedents"])
  end

  test "serves projection health for authenticated readers", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer reader-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> get("/api/v1/projections/health")

    assert %{
             "data" => %{
               "event_log_last_seq" => 14,
               "tenant_id" => "tenant-a"
             }
           } = json_response(conn, 200)
  end

  test "serves workflow inbox and workflow detail for authenticated readers", %{conn: conn} do
    inbox_conn =
      conn
      |> put_req_header("authorization", "Bearer reader-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> get("/api/v1/workflows")

    assert %{"data" => %{"items" => [%{"workflow_id" => "trace-123:exception:ex-42"} | _rest]}} =
             json_response(inbox_conn, 200)

    detail_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer reader-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> get("/api/v1/workflows/trace-123:exception:ex-42")

    assert %{"data" => %{"workflow" => %{"trace_id" => "trace-123"}}} =
             json_response(detail_conn, 200)
  end

  test "records workflow actions for authenticated writers", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer writer-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> post("/api/v1/workflows/trace-123:exception:ex-42/actions", %{
        "action" => "approve",
        "reason" => "manual approval complete"
      })

    assert %{"data" => %{"action" => %{"outcome" => "approve"}}} = json_response(conn, 200)
  end

  test "serves workflow studio templates and dry-run context for authenticated readers", %{
    conn: conn
  } do
    templates_conn =
      conn
      |> put_req_header("authorization", "Bearer reader-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> get("/api/v1/workflow-studio/templates")

    assert %{"data" => %{"templates" => [%{"template_id" => "incident_triage"} | _rest]}} =
             json_response(templates_conn, 200)

    overview_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer reader-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> get("/api/v1/workflow-studio/traces/trace-123")

    assert %{"data" => %{"draft" => %{"workflow_id" => "trace-123:trace_review:incident_triage"}}} =
             json_response(overview_conn, 200)
  end

  test "starts trace reviews for authenticated writers", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer writer-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> post("/api/v1/workflow-studio/traces/trace-123/reviews", %{
        "reason" => "incident triage requested",
        "template_id" => "incident_triage"
      })

    assert %{
             "data" => %{
               "created" => true,
               "workflow" => %{"workflow_id" => "trace-123:trace_review:incident_triage"}
             }
           } =
             json_response(conn, 201)
  end

  test "exports workflow audit payloads for admins", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer admin-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> get("/api/v1/admin/workflows/trace-123:exception:ex-42/export")

    assert %{
             "data" => %{
               "export_version" => 1,
               "workflow" => %{"workflow_id" => "trace-123:exception:ex-42"}
             }
           } =
             json_response(conn, 200)
  end

  test "blocks admin endpoints for non-admin accounts", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer reader-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> post("/api/v1/admin/replays", %{
        "mode" => "catch_up",
        "projection" => "trace_summary",
        "reason" => "reader should not be able to replay"
      })

    assert %{"error" => %{"code" => "forbidden"}} = json_response(conn, 403)
  end

  test "starts and inspects replay jobs for admins", %{conn: conn} do
    create_conn =
      conn
      |> put_req_header("authorization", "Bearer admin-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> post("/api/v1/admin/replays", %{
        "mode" => "rebuild",
        "projection" => "all",
        "reason" => "rebuild after projection drift"
      })

    assert %{
             "data" => %{
               "run" => %{
                 "job_id" => "job-1",
                 "mode" => "rebuild",
                 "projection_name" => "all",
                 "reason" => "rebuild after projection drift",
                 "status" => "queued",
                 "tenant_id" => "tenant-a"
               }
             }
           } = json_response(create_conn, 202)

    show_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer admin-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> get("/api/v1/admin/replays/job-1")

    assert %{"data" => %{"run" => %{"job_id" => "job-1", "status" => "completed"}}} =
             json_response(show_conn, 200)
  end

  test "admins can cancel replay jobs", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer admin-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> post("/api/v1/admin/replays/job-1/cancel")

    assert %{"data" => %{"run" => %{"job_id" => "job-1", "status" => "cancelled"}}} =
             json_response(conn, 200)
  end

  test "rate limiting returns 429 when a scope exceeds its budget", %{conn: conn} do
    Application.put_env(:dg_api, :rate_limits, %{admin: 5, read: 1, write: 5})

    first_conn =
      conn
      |> put_req_header("authorization", "Bearer reader-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> get("/api/v1/precedents")

    assert json_response(first_conn, 200)

    second_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer reader-test-token")
      |> put_req_header("x-tenant-id", "tenant-a")
      |> get("/api/v1/precedents")

    assert %{"error" => %{"code" => "rate_limited"}} = json_response(second_conn, 429)
  end
end
