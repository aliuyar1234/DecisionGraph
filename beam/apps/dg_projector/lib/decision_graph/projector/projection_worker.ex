defmodule DecisionGraph.Projector.ProjectionWorker do
  @moduledoc """
  Minimal supervised worker that models projector ownership and emits telemetry.
  """

  use GenServer

  alias DecisionGraph.Observability
  alias DecisionGraph.Projector.Runtime

  @type state :: %{
          key: Runtime.worker_key(),
          last_sync_at: DateTime.t() | nil,
          sync_count: non_neg_integer()
        }

  @spec start_link(Runtime.worker_key()) :: GenServer.on_start()
  def start_link(key) do
    GenServer.start_link(__MODULE__, key, name: Runtime.via(key))
  end

  @spec sync(Runtime.worker_key(), map()) :: :ok
  def sync(key, metadata \\ %{}) do
    GenServer.cast(Runtime.via(key), {:sync, metadata})
  end

  @spec status(Runtime.worker_key()) :: state()
  def status(key) do
    GenServer.call(Runtime.via(key), :status)
  end

  @impl true
  def init(key) do
    Observability.emit(
      [:projector, :worker, :started],
      %{count: 1},
      Map.merge(key, %{worker: worker_name(key)})
    )

    {:ok, %{key: key, last_sync_at: nil, sync_count: 0}}
  end

  @impl true
  def handle_call(:status, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast({:sync, metadata}, state) do
    now = DateTime.utc_now()

    Observability.emit(
      [:projector, :worker, :sync],
      %{count: 1},
      Map.merge(metadata, Map.merge(state.key, %{worker: worker_name(state.key)}))
    )

    {:noreply, %{state | last_sync_at: now, sync_count: state.sync_count + 1}}
  end

  defp worker_name(%{tenant_id: tenant_id, projection: projection, partition: partition}) do
    "#{tenant_id}:#{projection}:#{partition}"
  end
end
