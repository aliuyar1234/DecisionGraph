defmodule DecisionGraph.Projector.ProjectionWorker do
  @moduledoc """
  Supervised projector worker that owns periodic catch-up for one projection scope.
  """

  use GenServer

  alias DecisionGraph.Error
  alias DecisionGraph.Observability
  alias DecisionGraph.Projector.Engine
  alias DecisionGraph.Projector.Runtime
  alias DecisionGraph.Projector.Support
  alias DecisionGraph.Store

  @type state :: %{
          key: Runtime.worker_key(),
          cursor: non_neg_integer(),
          last_sync_at: DateTime.t() | nil,
          last_error: map() | nil,
          retry_count: non_neg_integer(),
          status: atom(),
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

    state = %{
      key: key,
      cursor: safe_cursor(key),
      last_sync_at: nil,
      last_error: nil,
      retry_count: 0,
      status: :idle,
      sync_count: 0
    }

    send(self(), {:sync, %{reason: "boot"}})
    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast({:sync, metadata}, state) do
    send(self(), {:sync, metadata})
    {:noreply, state}
  end

  @impl true
  def handle_info({:sync, metadata}, state) do
    now = DateTime.utc_now()

    case perform_sync(state) do
      {:ok, result} ->
        Observability.emit(
          [:projector, :worker, :sync],
          %{count: 1, processed_events: result.processed_events},
          Map.merge(metadata, Map.merge(state.key, %{worker: worker_name(state.key)}))
        )

        Process.send_after(self(), {:sync, %{reason: "poll"}}, poll_interval_ms())

        {:noreply,
         %{
           state
           | cursor: result.last_log_seq,
             last_sync_at: now,
             last_error: nil,
             retry_count: 0,
             status: :idle,
             sync_count: state.sync_count + 1
         }}

      {:error, error} ->
        retry_count = state.retry_count + 1
        recoverable? = Engine.failure_recoverable?(error)
        worker = worker_name(state.key)

        Observability.emit(
          [:projector, :worker, :exception],
          %{count: 1, retry_count: retry_count},
          Map.merge(metadata, Map.merge(state.key, %{worker: worker, error_code: error.code}))
        )

        if recoverable? and retry_count <= max_retries() do
          Process.send_after(self(), {:sync, %{reason: "retry"}}, retry_delay_ms(retry_count))
        else
          record_terminal_failure(state, error, retry_count)
        end

        {:noreply,
         %{
           state
           | last_sync_at: now,
             last_error: %{code: error.code, message: error.message, details: error.details},
             retry_count: retry_count,
             status:
               if(recoverable? and retry_count <= max_retries(), do: :retrying, else: :failed)
         }}
    end
  end

  defp worker_name(%{tenant_id: tenant_id, projection: projection, partition: partition}) do
    "#{tenant_id}:#{projection}:#{partition}"
  end

  defp poll_interval_ms do
    Application.get_env(:dg_projector, :projection_poll_interval_ms, 1_000)
  end

  defp max_retries do
    Application.get_env(:dg_projector, :projection_max_retries, 5)
  end

  defp retry_delay_ms(retry_count) do
    base = Application.get_env(:dg_projector, :projection_retry_base_ms, 250)
    base * trunc(:math.pow(2, retry_count - 1))
  end

  defp record_terminal_failure(state, error, retry_count) do
    failed_event = failed_event_for(state, error)

    if failed_event do
      Engine.record_failure!(
        state.key.projection,
        state.key.tenant_id,
        failed_event,
        error,
        retry_count: retry_count,
        recoverable: Engine.failure_recoverable?(error),
        processed_events: Map.get(error.details, :processed_events, 0)
      )
    end
  end

  defp safe_cursor(%{projection: projection, tenant_id: tenant_id}) do
    Store.get_projection_cursor(projection, tenant_id: tenant_id)
  rescue
    _error -> 0
  end

  defp perform_sync(state) do
    try do
      Engine.catch_up(state.key.projection, tenant_id: state.key.tenant_id)
    rescue
      error in Error ->
        {:error, error}

      error ->
        {:error, Support.wrap_error(error)}
    end
  end

  defp failed_event_for(state, error) do
    try do
      case Map.get(error.details, :event_id) do
        event_id when is_binary(event_id) and event_id != "" ->
          event_log_seq =
            Map.get(error.details, :log_seq, Map.get(error.details, :last_log_seq, 0))

          Store.list_events(
            tenant_id: state.key.tenant_id,
            since_log_seq: max(event_log_seq - 1, 0),
            until_log_seq: event_log_seq,
            limit: 16
          )
          |> Enum.find(&(&1.event_id == event_id))

        _ ->
          Store.list_events(
            tenant_id: state.key.tenant_id,
            since_log_seq: Map.get(error.details, :last_log_seq, 0),
            limit: 1
          )
          |> List.first()
      end
    rescue
      _error -> nil
    end
  end
end
