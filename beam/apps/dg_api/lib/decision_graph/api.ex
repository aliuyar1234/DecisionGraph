defmodule DecisionGraph.Api do
  @moduledoc """
  Service-facing bootstrap snapshot for the BEAM platform.
  """

  alias DecisionGraph.Api.{Health, ServiceAccount}

  @default_services %{
    admin: DecisionGraph.Api.Admin,
    console: DecisionGraph.Api.Console,
    events: DecisionGraph.Api.Events,
    graph: DecisionGraph.Api.Graph,
    precedents: DecisionGraph.Api.Precedents,
    traces: DecisionGraph.Api.Traces,
    workflows: DecisionGraph.Api.Workflows,
    workflow_studio: DecisionGraph.Api.WorkflowStudio
  }
  @default_admin_controls %{allow_rebuild: false, require_reason: true}
  @default_projector_module DecisionGraph.Projector

  @spec bootstrap_snapshot() :: map()
  def bootstrap_snapshot, do: Health.snapshot()

  @spec service(atom()) :: module()
  def service(name) when is_atom(name) do
    services = Application.get_env(:dg_api, :services, %{})
    Map.get(services, name, Map.fetch!(@default_services, name))
  end

  @spec operator_console_actor() :: ServiceAccount.t() | nil
  def operator_console_actor do
    cond do
      configured_actor = Application.get_env(:dg_api, :operator_console_actor) ->
        ServiceAccount.new(configured_actor)

      configured_account_id = Application.get_env(:dg_api, :operator_console_account_id) ->
        configured_account_id = to_string(configured_account_id)

        configured_service_accounts()
        |> Enum.find(&(&1.account_id == configured_account_id))

      true ->
        nil
    end
  end

  @spec admin_controls() :: map()
  def admin_controls do
    :dg_api
    |> Application.get_env(:admin_controls, %{})
    |> Map.new()
    |> then(&Map.merge(@default_admin_controls, &1))
  end

  @spec projector_module() :: module()
  def projector_module do
    Application.get_env(:dg_api, :projector_module, @default_projector_module)
  end

  defp configured_service_accounts do
    Application.get_env(:dg_api, :service_accounts, [])
    |> Enum.map(&ServiceAccount.new/1)
  end
end
