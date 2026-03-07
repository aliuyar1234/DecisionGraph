defmodule DecisionGraph.Projector do
  @moduledoc """
  Public entrypoint for the Phase 4 BEAM projection runtime.
  """

  alias DecisionGraph.Projector.{Engine, ProjectionWorker, ReplayCoordinator, Runtime}

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

  @spec worker_status(String.t(), atom() | String.t()) :: map()
  def worker_status(tenant_id, projection) do
    Runtime.worker_status(tenant_id, projection)
  end

  @spec replay(:all | atom() | String.t(), keyword()) ::
          {:ok, map()} | {:error, DecisionGraph.Error.t()}
  def replay(projection_name, opts \\ []) do
    ReplayCoordinator.start_replay(projection_name, opts)
  end

  @spec rebuild(:all | atom() | String.t(), keyword()) ::
          {:ok, map()} | {:error, DecisionGraph.Error.t()}
  def rebuild(projection_name, opts \\ []) do
    ReplayCoordinator.start_rebuild(projection_name, opts)
  end

  @spec cancel_replay(String.t()) :: :ok | {:error, DecisionGraph.Error.t()}
  def cancel_replay(job_id) do
    ReplayCoordinator.cancel(job_id)
  end

  @spec replay_status(String.t()) :: map() | nil
  def replay_status(job_id) do
    ReplayCoordinator.status(job_id)
  end

  @spec get_trace_summary(String.t(), keyword()) :: map()
  def get_trace_summary(trace_id, opts \\ []) do
    Engine.get_trace_summary(trace_id, opts)
  end

  @spec get_context_subgraph(map(), keyword()) :: map()
  def get_context_subgraph(center, opts \\ []) do
    Engine.get_context_subgraph(center, opts)
  end

  @spec list_node_edges(map(), keyword()) :: map()
  def list_node_edges(node, opts \\ []) do
    Engine.list_node_edges(node, opts)
  end

  @spec find_precedents(map() | keyword(), keyword()) :: list()
  def find_precedents(query, opts \\ []) do
    Engine.find_precedents(query, opts)
  end

  @spec projection_health(keyword()) :: map()
  def projection_health(opts \\ []) do
    Engine.projection_health(opts)
  end

  @spec list_runs(keyword()) :: [map()]
  def list_runs(opts \\ []) do
    Engine.list_runs(opts)
  end

  @spec list_failures(keyword()) :: [map()]
  def list_failures(opts \\ []) do
    Engine.list_failures(opts)
  end

  @spec runtime_snapshot() :: map()
  def runtime_snapshot do
    %{
      active_workers:
        DynamicSupervisor.count_children(DecisionGraph.Projector.WorkerSupervisor).active,
      active_replay_jobs: length(ReplayCoordinator.active_jobs()),
      partition_count: Runtime.partition_count(),
      projections: Enum.map(Runtime.projection_names(), &Atom.to_string/1)
    }
  end
end
