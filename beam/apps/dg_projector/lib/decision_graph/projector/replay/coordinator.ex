defmodule DecisionGraph.Projector.ReplayCoordinator do
  @moduledoc false

  use GenServer

  alias DecisionGraph.Error
  alias DecisionGraph.Observability
  alias DecisionGraph.Projector.Engine
  alias DecisionGraph.Projector.Support

  @type state :: %{
          jobs: %{optional(String.t()) => map()},
          scopes: %{optional(term()) => String.t()}
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec start_replay(:all | atom() | String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def start_replay(projection_name, opts \\ []) do
    GenServer.call(__MODULE__, {:start_job, projection_name, "catch_up", opts})
  end

  @spec start_rebuild(:all | atom() | String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def start_rebuild(projection_name, opts \\ []) do
    GenServer.call(__MODULE__, {:start_job, projection_name, "rebuild", opts})
  end

  @spec cancel(String.t()) :: :ok | {:error, Error.t()}
  def cancel(job_id) do
    GenServer.call(__MODULE__, {:cancel, job_id})
  end

  @spec status(String.t()) :: map() | nil
  def status(job_id) do
    Engine.get_run(job_id)
  end

  @spec active_jobs() :: [map()]
  def active_jobs do
    GenServer.call(__MODULE__, :active_jobs)
  end

  @impl true
  def init(_opts) do
    {:ok, %{jobs: %{}, scopes: %{}}}
  end

  @impl true
  def handle_call(:active_jobs, _from, state) do
    jobs =
      state.jobs
      |> Map.values()
      |> Enum.map(&Map.take(&1, [:job_id, :projection_name, :tenant_id, :mode]))

    {:reply, jobs, state}
  end

  def handle_call({:cancel, job_id}, _from, state) do
    case Map.get(state.jobs, job_id) do
      nil ->
        {:reply, {:error, Error.new(:not_found, "Replay job not found: #{job_id}")}, state}

      job ->
        Process.exit(job.task_pid, :kill)
        :ok = Engine.mark_run_cancelled!(job_id, job.processed_events, job.last_log_seq)

        emit_job_event(state, job_id, :cancelled, %{
          count: 1,
          duration: job_duration(state, job_id)
        })

        next_state =
          state
          |> remove_job(job_id)

        {:reply, :ok, next_state}
    end
  end

  def handle_call({:start_job, projection_name, mode, opts}, _from, state) do
    tenant_id = Support.normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))
    normalized_projection = normalize_job_projection(projection_name)
    scope = {tenant_id, normalized_projection}

    if Map.has_key?(state.scopes, scope) do
      {:reply,
       {:error,
        Error.new(
          :conflict,
          "A replay job is already running for #{tenant_id}/#{inspect(normalized_projection)}"
        )}, state}
    else
      job_id = "replay-" <> Integer.to_string(System.unique_integer([:positive]))

      run =
        Engine.create_run!(
          job_id,
          normalized_projection,
          mode,
          Keyword.put(opts, :tenant_id, tenant_id)
        )

      parent = self()

      {:ok, task_pid} =
        Task.Supervisor.start_child(DecisionGraph.Projector.ReplaySupervisor, fn ->
          execute_job(
            parent,
            job_id,
            normalized_projection,
            mode,
            Keyword.put(opts, :tenant_id, tenant_id)
          )
        end)

      next_state = %{
        state
        | jobs:
            Map.put(state.jobs, job_id, %{
              job_id: job_id,
              task_pid: task_pid,
              tenant_id: tenant_id,
              projection_name: normalized_projection,
              mode: mode,
              started_monotonic: System.monotonic_time(),
              processed_events: 0,
              last_log_seq: 0
            }),
          scopes: Map.put(state.scopes, scope, job_id)
      }

      Observability.emit(
        [:projector, :replay, :started],
        %{count: 1},
        %{
          job_id: job_id,
          mode: mode,
          projection: normalized_projection,
          tenant_id: tenant_id
        }
      )

      {:reply, {:ok, run}, next_state}
    end
  end

  @impl true
  def handle_info({:job_progress, job_id, processed_events, last_log_seq}, state) do
    next_state =
      update_in(state.jobs[job_id], fn
        nil -> nil
        job -> %{job | processed_events: processed_events, last_log_seq: last_log_seq}
      end)

    :ok = Engine.mark_run_progress!(job_id, processed_events, last_log_seq)

    emit_job_event(next_state, job_id, :progress, %{
      count: 1,
      last_log_seq: last_log_seq,
      processed_events: processed_events
    })

    {:noreply, next_state}
  end

  def handle_info({:job_finished, job_id, {:ok, result}}, state) do
    emit_job_event(state, job_id, :completed, %{
      count: 1,
      duration: job_duration(state, job_id),
      last_log_seq: result.last_log_seq,
      processed_events: result.processed_events
    })

    :ok = Engine.mark_run_completed!(job_id, result.processed_events, result.last_log_seq)
    {:noreply, remove_job(state, job_id)}
  end

  def handle_info({:job_finished, job_id, {:error, error, processed_events, last_log_seq}}, state) do
    emit_job_event(state, job_id, :failed, %{
      count: 1,
      duration: job_duration(state, job_id),
      last_log_seq: last_log_seq,
      processed_events: processed_events
    })

    :ok = Engine.mark_run_failed!(job_id, error, processed_events, last_log_seq)
    {:noreply, remove_job(state, job_id)}
  end

  defp execute_job(parent, job_id, projection_name, mode, opts) do
    :ok = Engine.mark_run_running!(job_id)

    result =
      try do
        case {projection_name, mode} do
          {:all, "rebuild"} ->
            Engine.rebuild_all(opts)
            |> case do
              {:ok, results} ->
                last_result = List.last(results) || %{last_log_seq: 0, processed_events: 0}

                {:ok,
                 %{
                   processed_events: Enum.reduce(results, 0, &(&1.processed_events + &2)),
                   last_log_seq: last_result.last_log_seq
                 }}

              {:error, %{error: error}} ->
                {:error, error}
            end

          {:all, "catch_up"} ->
            Support.projection_names()
            |> Enum.reduce_while({:ok, %{processed_events: 0, last_log_seq: 0}}, fn item,
                                                                                    {:ok, acc} ->
              case Engine.catch_up(item, opts) do
                {:ok, result} ->
                  send_progress(
                    parent,
                    job_id,
                    acc.processed_events + result.processed_events,
                    result.last_log_seq
                  )

                  {:cont,
                   {:ok,
                    %{
                      processed_events: acc.processed_events + result.processed_events,
                      last_log_seq: result.last_log_seq
                    }}}

                {:error, error} ->
                  {:halt, {:error, error}}
              end
            end)

          {_projection, "rebuild"} ->
            Engine.rebuild(projection_name, opts)

          {_projection, "catch_up"} ->
            Engine.catch_up(projection_name, opts)
        end
      rescue
        error in Error ->
          {:error, error}

        error ->
          {:error, Support.wrap_error(error)}
      end

    case result do
      {:ok, info} ->
        send_progress(parent, job_id, info.processed_events, info.last_log_seq)
        send(parent, {:job_finished, job_id, {:ok, info}})

      {:error, error} ->
        processed_events = Map.get(error.details, :processed_events, 0)
        last_log_seq = Map.get(error.details, :last_log_seq, 0)

        send(parent, {:job_finished, job_id, {:error, error, processed_events, last_log_seq}})
    end
  end

  defp send_progress(parent, job_id, processed_events, last_log_seq) do
    send(parent, {:job_progress, job_id, processed_events, last_log_seq})
  end

  defp normalize_job_projection(:all), do: :all
  defp normalize_job_projection("all"), do: :all

  defp normalize_job_projection(projection_name),
    do: Support.normalize_projection_name!(projection_name)

  defp remove_job(state, job_id) do
    case Map.get(state.jobs, job_id) do
      nil ->
        state

      job ->
        %{
          state
          | jobs: Map.delete(state.jobs, job_id),
            scopes: Map.delete(state.scopes, {job.tenant_id, job.projection_name})
        }
    end
  end

  defp emit_job_event(state, job_id, stage, measurements) do
    case Map.get(state.jobs, job_id) do
      nil ->
        :ok

      job ->
        Observability.emit(
          [:projector, :replay, stage],
          measurements,
          %{
            job_id: job.job_id,
            mode: job.mode,
            projection: job.projection_name,
            tenant_id: job.tenant_id
          }
        )
    end
  end

  defp job_duration(state, job_id) do
    case get_in(state.jobs, [job_id, :started_monotonic]) do
      nil -> 0
      started -> System.monotonic_time() - started
    end
  end
end
