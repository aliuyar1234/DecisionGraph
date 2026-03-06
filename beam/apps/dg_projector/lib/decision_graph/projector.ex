defmodule DecisionGraph.Projector do
  @moduledoc """
  Public entrypoint for the Phase 2 projector runtime shell.
  """

  alias DecisionGraph.Projector.{ProjectionWorker, Runtime}

  @spec ensure_worker_started(String.t(), atom() | String.t()) :: {:ok, pid()} | {:error, term()}
  def ensure_worker_started(tenant_id, projection) do
    Runtime.ensure_worker_started(tenant_id, projection)
  end

  @spec sync(String.t(), atom() | String.t(), map()) :: :ok
  def sync(tenant_id, projection, metadata \\ %{}) do
    tenant_id
    |> Runtime.worker_key(projection)
    |> ProjectionWorker.sync(metadata)
  end

  @spec runtime_snapshot() :: map()
  def runtime_snapshot do
    %{
      active_workers:
        DynamicSupervisor.count_children(DecisionGraph.Projector.WorkerSupervisor).active,
      partition_count: Runtime.partition_count(),
      projections: Enum.map(Runtime.projection_names(), &Atom.to_string/1)
    }
  end
end
