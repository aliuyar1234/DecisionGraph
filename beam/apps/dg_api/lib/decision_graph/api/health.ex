defmodule DecisionGraph.Api.Health do
  @moduledoc "Operational snapshot used by the Phase 2 web shell and health endpoints."

  alias DecisionGraph.Api.Serialization

  @spec snapshot() :: map()
  def snapshot do
    %{
      auth: auth_snapshot(),
      deployment_env: Application.get_env(:dg_api, :deployment_env, "dev"),
      observability: %{
        logger_metadata_keys: [:request_id, :trace_id, :tenant_id, :projection, :worker],
        otel_service_name: "decisiongraph-beam"
      },
      projection_health: projection_health_snapshot(),
      projector: DecisionGraph.Projector.runtime_snapshot(),
      store: DecisionGraph.Store.deployment_snapshot()
    }
  end

  defp auth_snapshot do
    %{
      bootstrap_source: Application.get_env(:dg_api, :bootstrap_source, "application_env"),
      configured_accounts: length(Application.get_env(:dg_api, :service_accounts, [])),
      operator_console_account_id: Application.get_env(:dg_api, :operator_console_account_id)
    }
  end

  defp projection_health_snapshot do
    DecisionGraph.Projector.projection_health()
    |> Serialization.serialize()
  rescue
    error ->
      %{
        status: "unavailable",
        reason: Exception.message(error)
      }
  end
end
