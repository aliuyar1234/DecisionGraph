defmodule DecisionGraph.Store.DataCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias DecisionGraph.Store.Repo
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      use ExUnitProperties

      alias DecisionGraph.Store
      alias DecisionGraph.Store.EventFactory
      alias DecisionGraph.Store.Repo
    end
  end

  setup _tags do
    :ok = Sandbox.checkout(Repo)
    Sandbox.mode(Repo, {:shared, self()})

    Enum.each(
      [
        "DELETE FROM dg_workflow_notifications",
        "DELETE FROM dg_workflow_actions",
        "DELETE FROM dg_workflow_items",
        "DELETE FROM dg_workflow_runtime",
        "DELETE FROM dg_projection_failures",
        "DELETE FROM dg_projection_runs",
        "DELETE FROM dg_projection_digests",
        "DELETE FROM dg_precedent_index",
        "DELETE FROM dg_policy_eval_index",
        "DELETE FROM dg_trace_summary",
        "DELETE FROM dg_cg_edges",
        "DELETE FROM dg_cg_nodes",
        "DELETE FROM dg_projection_cursors",
        "DELETE FROM dg_event_log",
        "ALTER SEQUENCE dg_event_log_log_seq_seq RESTART WITH 1"
      ],
      &Repo.query!/1
    )

    :ok
  end
end
