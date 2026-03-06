defmodule DecisionGraph.StoreTest do
  use ExUnit.Case, async: true

  test "reports deployment snapshot without requiring a live database" do
    snapshot = DecisionGraph.Store.deployment_snapshot()

    assert snapshot.database == "decisiongraph_beam_test"
    refute snapshot.repo_started?
  end
end
