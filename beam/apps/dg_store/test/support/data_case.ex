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

    Repo.query!("TRUNCATE TABLE dg_projection_cursors, dg_event_log RESTART IDENTITY CASCADE")

    :ok
  end
end
