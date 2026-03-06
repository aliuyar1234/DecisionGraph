defmodule DecisionGraph.Api.HealthTest do
  use ExUnit.Case, async: true

  test "returns bootstrap snapshot for the delivery layers" do
    snapshot = DecisionGraph.Api.bootstrap_snapshot()

    assert snapshot.deployment_env == "test"
    assert snapshot.projector.partition_count > 0
    assert snapshot.store.database == "decisiongraph_beam_test"
  end
end
