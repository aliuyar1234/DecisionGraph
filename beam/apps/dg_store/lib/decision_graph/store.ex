defmodule DecisionGraph.Store do
  @moduledoc """
  Bootstrap helpers for the Phase 2 store boundary.
  """

  alias DecisionGraph.Store.Repo

  @spec repo() :: module()
  def repo, do: Repo

  @spec repo_started?() :: boolean()
  def repo_started? do
    Application.get_env(:dg_store, :start_repo, false)
  end

  @spec deployment_snapshot() :: map()
  def deployment_snapshot do
    config = Repo.config()

    %{
      database: Keyword.get(config, :database),
      hostname: Keyword.get(config, :hostname),
      pool_size: Keyword.get(config, :pool_size),
      repo_started?: repo_started?(),
      telemetry_prefix: Keyword.get(config, :telemetry_prefix, [])
    }
  end
end
