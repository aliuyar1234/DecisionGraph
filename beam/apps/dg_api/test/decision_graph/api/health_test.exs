defmodule DecisionGraph.Api.HealthTest do
  use ExUnit.Case, async: true

  test "returns bootstrap snapshot for the delivery layers" do
    snapshot = DecisionGraph.Api.bootstrap_snapshot()

    assert snapshot.auth.configured_accounts > 0

    assert snapshot.auth.bootstrap_source in ["application_env", "env_json"] or
             String.starts_with?(snapshot.auth.bootstrap_source, "file:")

    assert snapshot.deployment_env == "test"
    assert snapshot.projector.partition_count > 0
    assert snapshot.store.database == "decisiongraph_beam_test"
  end
end
