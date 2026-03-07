defmodule DecisionGraph.Api.WorkflowsTest do
  use ExUnit.Case, async: false

  alias DecisionGraph.Api.ServiceAccount
  alias DecisionGraph.Api.Workflows
  alias DecisionGraph.Domain.EventEnvelope
  alias DecisionGraph.Store
  alias DecisionGraph.Store.EventFactory
  alias DecisionGraph.Store.Repo
  alias Ecto.Adapters.SQL.Sandbox

  setup_all do
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:dg_domain)
    {:ok, _} = Application.ensure_all_started(:dg_observability)
    {:ok, _} = Application.ensure_all_started(:dg_store)

    repo_config = Repo.config()

    case Ecto.Adapters.Postgres.storage_up(repo_config) do
      :ok -> :ok
      {:error, :already_up} -> :ok
    end

    case Repo.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    migrations_path = Application.app_dir(:dg_store, "priv/repo/migrations")

    {:ok, _, _} =
      Ecto.Migrator.with_repo(Repo, fn repo ->
        Ecto.Migrator.run(repo, migrations_path, :up, all: true)
      end)

    :ok
  end

  setup do
    :ok = Sandbox.checkout(Repo)
    Sandbox.mode(Repo, {:shared, self()})
    clear_tables!()

    previous_services = Application.get_env(:dg_api, :services)

    Application.put_env(:dg_api, :services, %{
      events: DecisionGraph.Api.WorkflowEventServiceFake,
      precedents: DecisionGraph.Api.WorkflowPrecedentServiceFake,
      traces: DecisionGraph.Api.WorkflowTraceServiceFake
    })

    on_exit(fn ->
      if previous_services,
        do: Application.put_env(:dg_api, :services, previous_services),
        else: Application.delete_env(:dg_api, :services)
    end)

    :ok
  end

  test "builds inbox items from exception request events" do
    append_exception_review_trace!("trace-42", "tenant-a")

    assert {:ok, inbox} = Workflows.list_inbox(%{}, tenant_id: "tenant-a")

    assert inbox.summary["open_count"] == 1

    assert [%{"workflow_id" => "trace-42:exception:ex-42", "status" => status}] =
             Enum.map(inbox.items, &Map.take(&1, ["workflow_id", "status"]))

    assert status in ["requested", "escalated"]
  end

  test "approve actions append ApprovalRecorded and close the workflow" do
    append_exception_review_trace!("trace-42", "tenant-a")

    actor =
      ServiceAccount.new(%{
        account_id: "workflow-admin",
        permissions: ["workflow_review"],
        roles: ["admin"],
        tenant_ids: ["tenant-a"],
        token: "token"
      })

    assert {:ok, result} =
             Workflows.act_on_workflow(
               "trace-42:exception:ex-42",
               %{"action" => "approve", "reason" => "review complete"},
               tenant_id: "tenant-a",
               actor: actor,
               request_id: "req-approve"
             )

    assert result.workflow["status"] == "approved"

    events = Store.get_trace_events("trace-42", tenant_id: "tenant-a")
    approval = List.last(events)

    assert approval.event_type == "ApprovalRecorded"
    assert approval.payload["decision"] == "approved"
    assert approval.payload["subject"]["subject_id"] == "ex-42"
  end

  test "overdue workflows auto-escalate and emit notification records" do
    append_exception_review_trace!("trace-overdue", "tenant-a", "2026-03-01T10:02:00Z")

    assert {:ok, inbox} = Workflows.list_inbox(%{}, tenant_id: "tenant-a")
    assert inbox.summary["escalated_count"] == 1
    assert [%{"status" => "escalated"}] = Enum.map(inbox.items, &Map.take(&1, ["status"]))

    assert {:ok, detail} =
             Workflows.get_workflow("trace-overdue:exception:ex-42", tenant_id: "tenant-a")

    assert Enum.any?(detail.notifications, &(&1["category"] == "escalation"))
    assert Enum.any?(detail.actions, &(&1["action_type"] == "escalate"))
  end

  test "override actions enforce the stronger override permission" do
    append_exception_review_trace!("trace-42", "tenant-a")

    actor =
      ServiceAccount.new(%{
        account_id: "workflow-reviewer",
        permissions: ["workflow_review"],
        roles: ["writer"],
        tenant_ids: ["tenant-a"],
        token: "token"
      })

    assert {:error, error} =
             Workflows.act_on_workflow(
               "trace-42:exception:ex-42",
               %{
                 "action" => "override",
                 "confirm_text" => "OVERRIDE TRACE-42:EXCEPTION:EX-42",
                 "reason" => "operator override requested"
               },
               tenant_id: "tenant-a",
               actor: actor,
               request_id: "req-override"
             )

    assert error.code == "forbidden"
  end

  test "manual escalation enforces the stronger escalation permission" do
    append_exception_review_trace!("trace-42", "tenant-a")

    actor =
      ServiceAccount.new(%{
        account_id: "workflow-reviewer",
        permissions: ["workflow_review"],
        roles: ["writer"],
        tenant_ids: ["tenant-a"],
        token: "token"
      })

    assert {:error, error} =
             Workflows.act_on_workflow(
               "trace-42:exception:ex-42",
               %{
                 "action" => "escalate",
                 "reason" => "finance leadership required"
               },
               tenant_id: "tenant-a",
               actor: actor,
               request_id: "req-escalate"
             )

    assert error.code == "forbidden"
  end

  test "starting a trace review appends WorkflowReviewRequested and creates an incident workflow" do
    Store.append_event(EventFactory.trace_started("trace-77"), tenant_id: "tenant-a")
    Store.append_event(EventFactory.policy_evaluated("trace-77", 1), tenant_id: "tenant-a")

    actor =
      ServiceAccount.new(%{
        account_id: "workflow-admin",
        permissions: ["workflow_assign", "workflow_review", "workflow_escalate"],
        roles: ["admin"],
        tenant_ids: ["tenant-a"],
        token: "token"
      })

    assert {:ok, result} =
             Workflows.start_trace_review(
               "trace-77",
               %{
                 "reason" => "unexpected precedent drift",
                 "template_id" => "incident_triage"
               },
               tenant_id: "tenant-a",
               actor: actor,
               request_id: "req-start-review"
             )

    assert result.created
    assert result.workflow["workflow_id"] == "trace-77:trace_review:incident_triage"

    events = Store.get_trace_events("trace-77", tenant_id: "tenant-a")
    review_event = List.last(events)

    assert review_event.event_type == "WorkflowReviewRequested"
    assert review_event.payload["template_id"] == "incident_triage"
  end

  defp clear_tables! do
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

  defp append_exception_review_trace!(trace_id, tenant_id, occurred_at \\ "2026-03-07T10:02:00Z") do
    Store.append_event(EventFactory.trace_started(trace_id), tenant_id: tenant_id)
    Store.append_event(EventFactory.policy_evaluated(trace_id, 1), tenant_id: tenant_id)

    Store.append_event(
      EventEnvelope.new(%{
        actor: %{actor_id: "policy-engine", actor_type: "system"},
        event_id: "#{trace_id}-exception-2",
        event_type: "ExceptionRequested",
        idempotency_key: "exception:#{trace_id}:2",
        occurred_at: occurred_at,
        payload: %{
          "evidence" => [%{"locator" => "policy://discount-cap#threshold"}],
          "exception_id" => "ex-42",
          "policy" => %{"policy_id" => "discount-cap", "policy_version" => "2026.03"},
          "reason" => "Strategic renewal over threshold"
        },
        source: %{producer_id: "policy-engine", subsystem: "policy", system: "decisiongraph"},
        trace_id: trace_id,
        trace_seq: 2
      }),
      tenant_id: tenant_id
    )
  end
end

defmodule DecisionGraph.Api.WorkflowEventServiceFake do
  alias DecisionGraph.Domain.EventEnvelope
  alias DecisionGraph.Store

  def append_event(attrs, opts) do
    envelope = EventEnvelope.new(attrs)
    stored_event = Store.append_event(envelope, opts)
    {:ok, %{event: stored_event, projection_sync_triggered: false}}
  end
end

defmodule DecisionGraph.Api.WorkflowTraceServiceFake do
  alias DecisionGraph.Store

  def get_trace(trace_id, opts) do
    {:ok,
     %{
       events: Store.get_trace_events(trace_id, tenant_id: Keyword.fetch!(opts, :tenant_id)),
       summary: %{
         finished_at: "2026-03-07T10:06:00Z",
         outcome: "review_required",
         primary_entity_id: "deal-42",
         primary_entity_system: "crm",
         primary_entity_type: "deal",
         tenant_id: Keyword.fetch!(opts, :tenant_id),
         title: "Trace #{trace_id}",
         trace_id: trace_id,
         workflow: "workflow_test"
       }
     }}
  end
end

defmodule DecisionGraph.Api.WorkflowPrecedentServiceFake do
  def find_precedents(_params, _opts) do
    {:ok,
     [
       %{outcome: "approved", trace_id: "precedent-1"},
       %{outcome: "rejected", trace_id: "precedent-2"}
     ]}
  end
end
