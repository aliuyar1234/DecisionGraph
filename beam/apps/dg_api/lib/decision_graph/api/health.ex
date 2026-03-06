defmodule DecisionGraph.Api.Health do
  @moduledoc "Operational snapshot used by the Phase 2 web shell and health endpoints."

  @spec snapshot() :: map()
  def snapshot do
    %{
      deployment_env: Application.get_env(:dg_api, :deployment_env, "dev"),
      observability: %{
        logger_metadata_keys: [:request_id, :trace_id, :tenant_id, :projection, :worker],
        otel_service_name: "decisiongraph-beam"
      },
      projector: DecisionGraph.Projector.runtime_snapshot(),
      store: DecisionGraph.Store.deployment_snapshot()
    }
  end
end
