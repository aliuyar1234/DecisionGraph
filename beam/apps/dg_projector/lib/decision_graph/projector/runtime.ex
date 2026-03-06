defmodule DecisionGraph.Projector.Runtime do
  @moduledoc """
  Naming and sharding conventions for projector workers.
  """

  alias DecisionGraph.Projector.ProjectionWorker

  @projection_names [:context_graph, :trace_summary, :precedent_index]

  @type worker_key :: %{
          tenant_id: String.t(),
          projection: atom(),
          partition: non_neg_integer()
        }

  @spec projection_names() :: [atom()]
  def projection_names, do: @projection_names

  @spec partition_count() :: pos_integer()
  def partition_count do
    Application.get_env(:dg_projector, :projection_partitions, 8)
  end

  @spec normalize_projection(atom() | String.t()) :: atom()
  def normalize_projection(projection) when projection in @projection_names, do: projection

  def normalize_projection(projection) when is_binary(projection) do
    normalized_projection = String.trim(projection)

    Enum.find(@projection_names, fn known_projection ->
      Atom.to_string(known_projection) == normalized_projection
    end) || raise(ArgumentError, "unknown projection #{inspect(projection)}")
  end

  @spec partition_for(String.t(), atom() | String.t()) :: non_neg_integer()
  def partition_for(tenant_id, projection) do
    normalized_projection = normalize_projection(projection)
    :erlang.phash2({normalize_tenant_id(tenant_id), normalized_projection}, partition_count())
  end

  @spec worker_key(String.t(), atom() | String.t()) :: worker_key()
  def worker_key(tenant_id, projection) do
    normalized_projection = normalize_projection(projection)

    %{
      tenant_id: normalize_tenant_id(tenant_id),
      projection: normalized_projection,
      partition: partition_for(tenant_id, normalized_projection)
    }
  end

  @spec ensure_worker_started(String.t(), atom() | String.t()) :: {:ok, pid()} | {:error, term()}
  def ensure_worker_started(tenant_id, projection) do
    key = worker_key(tenant_id, projection)

    case DynamicSupervisor.start_child(
           DecisionGraph.Projector.WorkerSupervisor,
           {ProjectionWorker, key}
         ) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, {:shutdown, {:failed_to_start_child, _, {:already_started, pid}}}} -> {:ok, pid}
      other -> other
    end
  end

  @spec via(worker_key()) :: {:via, Registry, {module(), String.t()}}
  def via(%{tenant_id: tenant_id, projection: projection, partition: partition}) do
    {:via, Registry,
     {DecisionGraph.Projector.Registry, "#{tenant_id}:#{projection}:#{partition}"}}
  end

  defp normalize_tenant_id(tenant_id) when is_binary(tenant_id) do
    tenant_id
    |> String.trim()
    |> case do
      "" -> "default"
      value -> value
    end
  end

  defp normalize_tenant_id(tenant_id), do: normalize_tenant_id(to_string(tenant_id))
end
