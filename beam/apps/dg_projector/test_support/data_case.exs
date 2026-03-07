defmodule DecisionGraph.Projector.DataCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias DecisionGraph.Store.Repo
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias DecisionGraph.Domain.EventEnvelope
      alias DecisionGraph.Error
      alias DecisionGraph.Projector
      alias DecisionGraph.Projector.{Digests, Engine, GraphFilter, NodeRef, SQL}
      alias DecisionGraph.Store
      alias DecisionGraph.Store.Repo
    end
  end

  setup _tags do
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:dg_store)

    case Repo.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    :ok = Sandbox.checkout(Repo)
    Sandbox.mode(Repo, {:shared, self()})

    Repo.query!("""
    TRUNCATE TABLE
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

    :ok
  end
end
