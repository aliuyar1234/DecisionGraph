defmodule DecisionGraphWeb.ServiceApiE2ETest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Plug.Conn

  alias DecisionGraph.Store.Repo
  alias Ecto.Adapters.SQL.Sandbox

  @endpoint DecisionGraphWeb.Endpoint
  @fixture_bundle_path Path.expand(
                         "../../../../../../tests/golden/reference_fixture_bundle.json",
                         __DIR__
                       )
  @bundle File.read!(@fixture_bundle_path) |> Jason.decode!()
  @dealdesk Enum.find(@bundle["scenarios"], &(&1["scenario"] == "dealdesk"))

  setup do
    if System.get_env("DG_RUN_SERVICE_E2E") == "1" do
      previous_services = Application.get_env(:dg_api, :services)
      previous_limits = Application.get_env(:dg_api, :rate_limits)

      Application.delete_env(:dg_api, :services)
      Application.put_env(:dg_api, :rate_limits, %{admin: 1_000, read: 5_000, write: 1_000})

      {:ok, _} = Application.ensure_all_started(:ecto_sql)
      {:ok, _} = Application.ensure_all_started(:postgrex)
      {:ok, _} = Application.ensure_all_started(:dg_store)
      {:ok, _} = Application.ensure_all_started(:dg_projector)

      case Repo.start_link() do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
      end

      owner = Sandbox.start_owner!(Repo, shared: true)

      truncate_projection_tables!()
      clear_rate_limiter!()

      on_exit(fn ->
        wait_for_idle_projector_workers!()
        stop_projector_workers!()
        Application.stop(:dg_projector)
        Process.sleep(50)
        Sandbox.stop_owner(owner)

        if previous_services,
          do: Application.put_env(:dg_api, :services, previous_services),
          else: Application.delete_env(:dg_api, :services)

        if previous_limits,
          do: Application.put_env(:dg_api, :rate_limits, previous_limits),
          else: Application.delete_env(:dg_api, :rate_limits)
      end)

      {:ok, conn: Phoenix.ConnTest.build_conn()}
    else
      {:ok, conn: Phoenix.ConnTest.build_conn(), run_service_e2e?: false}
    end
  end

  test "authenticated writes flow through projections into trace and health reads",
       %{conn: conn} = context do
    run_service_e2e? = Map.get(context, :run_service_e2e?, true)

    if run_service_e2e? do
      trace_id = @dealdesk["trace_id"]
      event_count = @dealdesk["event_count"]
      projection_cursor = @dealdesk["projection_snapshot"]["projection_cursor"]

      Enum.each(@dealdesk["events"], fn event ->
        event_conn =
          conn
          |> recycle()
          |> auth_headers("writer-test-token", "tenant-a")
          |> post("/api/v1/events", event)

        assert %{"data" => %{"event" => %{"trace_id" => ^trace_id}}} =
                 json_response(event_conn, 201)
      end)

      trace_response =
        wait_until(fn ->
          response =
            build_conn()
            |> auth_headers("reader-test-token", "tenant-a")
            |> get("/api/v1/traces/#{trace_id}")

          case response.status do
            200 -> Jason.decode!(response.resp_body)
            409 -> nil
            _ -> flunk("unexpected trace response status #{inspect(response.status)}")
          end
        end)

      events = get_in(trace_response, ["data", "events"])
      summary = get_in(trace_response, ["data", "summary"])

      assert is_list(events)
      assert length(events) == event_count
      assert is_map(summary)
      assert summary["trace_id"] == trace_id
      assert summary["workflow"] == @dealdesk["projection_snapshot"]["trace_summary"]["workflow"]

      health_response =
        wait_until(fn ->
          response =
            build_conn()
            |> auth_headers("reader-test-token", "tenant-a")
            |> get("/api/v1/projections/health")

          case response.status do
            200 ->
              body = Jason.decode!(response.resp_body)
              projections = get_in(body, ["data", "projections"]) || []

              if Enum.all?(projections, fn projection ->
                   projection["last_log_seq"] == projection_cursor and
                     projection["pending_events"] == 0 and
                     projection["is_stale"] == false
                 end) do
                body
              end

            409 ->
              nil

            _ ->
              flunk("unexpected projection health status #{inspect(response.status)}")
          end
        end)

      assert %{
               "data" => %{
                 "event_log_last_seq" => event_log_last_seq,
                 "projections" => projections,
                 "tenant_id" => "tenant-a"
               }
             } = health_response

      assert event_log_last_seq == projection_cursor
      assert Enum.any?(projections, &(&1["projection_name"] == "trace_summary"))
      assert Enum.any?(projections, &(&1["projection_name"] == "context_graph"))
      assert Enum.any?(projections, &(&1["projection_name"] == "precedent_index"))
    else
      assert true
    end
  end

  test "workflow inbox and approval actions run through the authenticated service API",
       %{conn: conn} = context do
    run_service_e2e? = Map.get(context, :run_service_e2e?, true)

    if run_service_e2e? do
      trace_id = "workflow-e2e-trace"
      workflow_id = "#{trace_id}:exception:ex-workflow-1"

      Enum.each(workflow_trace_events(trace_id), fn event ->
        event_conn =
          conn
          |> recycle()
          |> auth_headers("writer-test-token", "tenant-a")
          |> post("/api/v1/events", event)

        assert json_response(event_conn, 201)
      end)

      inbox_response =
        wait_until(fn ->
          response =
            build_conn()
            |> auth_headers("reader-test-token", "tenant-a")
            |> get("/api/v1/workflows")

          case response.status do
            200 ->
              body = Jason.decode!(response.resp_body)

              if Enum.any?(
                   get_in(body, ["data", "items"]) || [],
                   &(&1["workflow_id"] == workflow_id)
                 ) do
                body
              end

            _other ->
              nil
          end
        end)

      assert %{"data" => %{"summary" => %{"open_count" => open_count}}} = inbox_response
      assert open_count >= 1

      approve_conn =
        build_conn()
        |> auth_headers("writer-test-token", "tenant-a")
        |> post("/api/v1/workflows/#{workflow_id}/actions", %{
          "action" => "approve",
          "reason" => "workflow e2e approval"
        })

      assert %{"data" => %{"workflow" => %{"status" => "approved"}}} =
               json_response(approve_conn, 200)

      detail_response =
        wait_until(fn ->
          response =
            build_conn()
            |> auth_headers("reader-test-token", "tenant-a")
            |> get("/api/v1/workflows/#{workflow_id}")

          case response.status do
            200 ->
              body = Jason.decode!(response.resp_body)

              if get_in(body, ["data", "workflow", "status"]) == "approved" do
                body
              end

            _other ->
              nil
          end
        end)

      assert %{
               "data" => %{
                 "actions" => actions,
                 "workflow" => %{"status" => "approved", "trace_id" => ^trace_id}
               }
             } = detail_response

      assert Enum.any?(actions, &(&1["action_type"] == "approve"))

      export_conn =
        build_conn()
        |> auth_headers("admin-test-token", "tenant-a")
        |> get("/api/v1/admin/workflows/#{workflow_id}/export")

      assert %{"data" => %{"export_version" => 1, "workflow" => %{"workflow_id" => ^workflow_id}}} =
               json_response(export_conn, 200)
    else
      assert true
    end
  end

  test "workflow studio can start trace reviews through the authenticated service API",
       %{conn: conn} = context do
    run_service_e2e? = Map.get(context, :run_service_e2e?, true)

    if run_service_e2e? do
      trace_id = "workflow-studio-e2e-trace"
      workflow_id = "#{trace_id}:trace_review:incident_triage"

      Enum.each(workflow_trace_events(trace_id), fn event ->
        event_conn =
          conn
          |> recycle()
          |> auth_headers("writer-test-token", "tenant-a")
          |> post("/api/v1/events", event)

        assert json_response(event_conn, 201)
      end)

      create_conn =
        build_conn()
        |> auth_headers("writer-test-token", "tenant-a")
        |> post("/api/v1/workflow-studio/traces/#{trace_id}/reviews", %{
          "reason" => "studio e2e incident review",
          "template_id" => "incident_triage"
        })

      assert %{"data" => %{"created" => true, "workflow" => %{"workflow_id" => ^workflow_id}}} =
               json_response(create_conn, 201)

      detail_response =
        wait_until(fn ->
          response =
            build_conn()
            |> auth_headers("reader-test-token", "tenant-a")
            |> get("/api/v1/workflows/#{workflow_id}")

          case response.status do
            200 ->
              body = Jason.decode!(response.resp_body)

              if get_in(body, ["data", "workflow", "workflow_kind"]) == "incident_review" do
                body
              end

            _other ->
              nil
          end
        end)

      assert %{
               "data" => %{
                 "notifications" => notifications,
                 "workflow" => %{"workflow_kind" => "incident_review", "trace_id" => ^trace_id}
               }
             } = detail_response

      assert Enum.any?(notifications, &(&1["category"] == "assignment"))
    else
      assert true
    end
  end

  defp auth_headers(conn, token, tenant_id) do
    conn
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("x-tenant-id", tenant_id)
  end

  defp clear_rate_limiter! do
    case :ets.whereis(:decision_graph_api_rate_limiter) do
      :undefined -> :ok
      table -> :ets.delete_all_objects(table)
    end
  end

  defp stop_projector_workers! do
    workers =
      DecisionGraph.Projector.WorkerSupervisor
      |> DynamicSupervisor.which_children()
      |> Enum.flat_map(fn
        {_id, pid, :worker, _modules} when is_pid(pid) -> [pid]
        _other -> []
      end)

    Enum.each(workers, fn pid ->
      DynamicSupervisor.terminate_child(DecisionGraph.Projector.WorkerSupervisor, pid)
    end)

    wait_until_workers_stopped!(workers)
  end

  defp wait_for_idle_projector_workers!(attempts \\ 50)

  defp wait_for_idle_projector_workers!(attempts) when attempts > 0 do
    workers =
      DecisionGraph.Projector.WorkerSupervisor
      |> DynamicSupervisor.which_children()
      |> Enum.filter(fn
        {_id, pid, :worker, _modules} when is_pid(pid) -> true
        _other -> false
      end)

    if Enum.all?(workers, fn {_id, pid, :worker, _modules} ->
         try do
           state = :sys.get_state(pid)
           mailbox_len = Process.info(pid, :message_queue_len) |> elem(1)
           state.status == :idle and mailbox_len == 0
         catch
           :exit, _reason -> true
         end
       end) do
      :ok
    else
      Process.sleep(20)
      wait_for_idle_projector_workers!(attempts - 1)
    end
  end

  defp wait_for_idle_projector_workers!(0), do: :ok

  defp wait_until_workers_stopped!(workers, attempts \\ 50)

  defp wait_until_workers_stopped!(workers, attempts) when attempts > 0 do
    if Enum.all?(workers, &(not Process.alive?(&1))) do
      :ok
    else
      Process.sleep(20)
      wait_until_workers_stopped!(workers, attempts - 1)
    end
  end

  defp wait_until_workers_stopped!(_workers, 0), do: :ok

  defp truncate_projection_tables! do
    Repo.query!("""
    TRUNCATE TABLE
      dg_workflow_notifications,
      dg_workflow_actions,
      dg_workflow_items,
      dg_workflow_runtime,
      dg_projection_failures,
      dg_projection_runs,
      dg_projection_digests,
      dg_precedent_index,
      dg_policy_eval_index,
      dg_trace_summary,
      dg_cg_edges,
      dg_cg_nodes,
      dg_projection_cursors,
      dg_event_log
    RESTART IDENTITY CASCADE
    """)
  end

  defp wait_until(fun, attempts \\ 150)

  defp wait_until(fun, attempts) when attempts > 0 do
    case fun.() do
      nil ->
        Process.sleep(20)
        wait_until(fun, attempts - 1)

      result ->
        result
    end
  end

  defp wait_until(_fun, 0) do
    flunk("timed out waiting for API projections to become readable")
  end

  defp workflow_trace_events(trace_id) do
    [
      %{
        "actor" => %{"actor_id" => "workflow-agent", "actor_type" => "agent"},
        "event_id" => "#{trace_id}-trace-started-0",
        "event_type" => "TraceStarted",
        "idempotency_key" => "start:#{trace_id}",
        "occurred_at" => "2026-03-07T12:00:00Z",
        "payload" => %{
          "primary_entity" => %{
            "entity_id" => "deal-workflow-1",
            "entity_type" => "deal",
            "system" => "crm"
          },
          "title" => "Workflow API approval",
          "workflow" => "workflow_e2e"
        },
        "source" => %{
          "producer_id" => "workflow-e2e",
          "subsystem" => "api-test",
          "system" => "decisiongraph"
        },
        "trace_id" => trace_id,
        "trace_seq" => 0
      },
      %{
        "actor" => %{"actor_id" => "policy-engine", "actor_type" => "system"},
        "event_id" => "#{trace_id}-policy-evaluated-1",
        "event_type" => "PolicyEvaluated",
        "idempotency_key" => "policy:#{trace_id}:1",
        "occurred_at" => "2026-03-07T12:01:00Z",
        "payload" => %{
          "decision" => "require_exception",
          "inputs" => ["deal-workflow-1"],
          "policy" => %{"policy_id" => "discount-cap", "policy_version" => "2026.03"},
          "violations" => [%{"code" => "threshold"}]
        },
        "source" => %{
          "producer_id" => "workflow-e2e",
          "subsystem" => "api-test",
          "system" => "decisiongraph"
        },
        "trace_id" => trace_id,
        "trace_seq" => 1
      },
      %{
        "actor" => %{"actor_id" => "policy-engine", "actor_type" => "system"},
        "event_id" => "#{trace_id}-exception-requested-2",
        "event_type" => "ExceptionRequested",
        "idempotency_key" => "exception:#{trace_id}:2",
        "occurred_at" => "2026-03-07T12:02:00Z",
        "payload" => %{
          "evidence" => [%{"locator" => "policy://discount-cap#threshold"}],
          "exception_id" => "ex-workflow-1",
          "policy" => %{"policy_id" => "discount-cap", "policy_version" => "2026.03"},
          "reason" => "Strategic renewal needs manual approval"
        },
        "source" => %{
          "producer_id" => "workflow-e2e",
          "subsystem" => "api-test",
          "system" => "decisiongraph"
        },
        "trace_id" => trace_id,
        "trace_seq" => 2
      }
    ]
  end
end
