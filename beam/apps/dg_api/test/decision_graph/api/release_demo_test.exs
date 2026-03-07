defmodule DecisionGraph.Api.ReleaseDemoTest do
  use DecisionGraph.Store.DataCase, async: false

  alias DecisionGraph.Api.ReleaseDemo
  alias DecisionGraph.Store.Repo

  setup_all do
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:dg_store)
    {:ok, _} = Application.ensure_all_started(:dg_projector)
    {:ok, _} = Application.ensure_all_started(:dg_api)

    case Repo.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    :ok
  end

  test "seed creates operator-ready traces, precedents, and workflows" do
    report = ReleaseDemo.seed(tenant_id: "release-demo-test")

    assert report.seed_profile == "phase10_release_demo"
    assert report.event_count == 22
    assert report.live_trace.trace_id == ReleaseDemo.live_trace_id()
    assert report.live_trace.workflow_status == "escalated"
    assert report.review_workflow.workflow_id == ReleaseDemo.incident_review_workflow_id()
    assert report.review_workflow.workflow_status == "escalated"
    assert report.workflow_inbox.open_count == 2
    assert report.console_snapshot.selected_trace_id == ReleaseDemo.live_trace_id()
    assert report.console_snapshot.selected_workflow_id == ReleaseDemo.live_workflow_id()
    assert ReleaseDemo.precedent_trace_id() in report.live_trace.precedent_trace_ids
    assert Map.has_key?(report.projection_digests, "trace_summary")
    assert Map.has_key?(report.projection_digests, "context_graph")
    assert Map.has_key?(report.projection_digests, "precedent_index")
  end

  test "seed resets workflow notifications for the tenant before reseeding" do
    tenant_id = "release-demo-repeat"

    first = ReleaseDemo.seed(tenant_id: tenant_id)
    first_counts = tenant_counts(tenant_id)

    second = ReleaseDemo.seed(tenant_id: tenant_id)
    second_counts = tenant_counts(tenant_id)

    assert first.event_count == second.event_count
    assert first_counts == second_counts
    assert first_counts == %{event_count: 22, notification_count: 8, workflow_count: 4}
  end

  defp tenant_counts(tenant_id) do
    %{
      event_count:
        Repo.query!(
          "SELECT COUNT(*) AS count FROM dg_event_log WHERE tenant_id = $1",
          [tenant_id]
        ).rows
        |> List.first()
        |> List.first(),
      notification_count:
        Repo.query!(
          "SELECT COUNT(*) AS count FROM dg_workflow_notifications WHERE tenant_id = $1",
          [tenant_id]
        ).rows
        |> List.first()
        |> List.first(),
      workflow_count:
        Repo.query!(
          "SELECT COUNT(*) AS count FROM dg_workflow_items WHERE tenant_id = $1",
          [tenant_id]
        ).rows
        |> List.first()
        |> List.first()
    }
  end
end
