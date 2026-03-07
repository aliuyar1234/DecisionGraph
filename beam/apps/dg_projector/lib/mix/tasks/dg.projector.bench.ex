defmodule Mix.Tasks.Dg.Projector.Bench do
  @shortdoc "Benchmarks DecisionGraph projector rebuild and incremental catch-up throughput"

  use Mix.Task

  alias DecisionGraph.Domain.EventEnvelope
  alias DecisionGraph.Projector.Engine
  alias DecisionGraph.Projector.Support
  alias DecisionGraph.Store
  alias DecisionGraph.Store.Repo
  alias Ecto.Adapters.Postgres
  alias Ecto.Migrator
  require Logger

  @requirements ["loadpaths"]
  @default_batch_size 250
  @default_events_per_trace 6
  @default_payload_bytes 512
  @default_traces 100

  @impl true
  def run(args) do
    opts = parse_args!(args)
    tenant_id = Keyword.fetch!(opts, :tenant_id)
    run_token = benchmark_run_token(tenant_id)

    Logger.configure(level: :warning)

    ensure_storage_ready!()
    :ok = Store.clear(tenant_id: tenant_id)

    baseline_events =
      build_events(
        "baseline",
        run_token,
        Keyword.fetch!(opts, :traces),
        Keyword.fetch!(opts, :events_per_trace),
        Keyword.fetch!(opts, :payload_bytes)
      )

    baseline_count =
      baseline_events
      |> Enum.map(&Store.append_event(&1, tenant_id: tenant_id))
      |> length()

    batch_size = Keyword.fetch!(opts, :batch_size)

    {replay_us, replay_results} =
      :timer.tc(fn ->
        Engine.rebuild_all(tenant_id: tenant_id, batch_size: batch_size)
      end)

    {:ok, replay_results} = replay_results
    replay_projection_events = Enum.reduce(replay_results, 0, &(&1.processed_events + &2))

    incremental_events =
      build_events(
        "incremental",
        run_token,
        Keyword.fetch!(opts, :traces),
        Keyword.fetch!(opts, :events_per_trace),
        Keyword.fetch!(opts, :payload_bytes)
      )

    incremental_count =
      incremental_events
      |> Enum.map(&Store.append_event(&1, tenant_id: tenant_id))
      |> length()

    {catch_up_us, catch_up_results} =
      :timer.tc(fn ->
        Support.projection_names()
        |> Enum.map(fn projection_name ->
          {:ok, result} =
            Engine.catch_up(projection_name, tenant_id: tenant_id, batch_size: batch_size)

          result
        end)
      end)

    catch_up_projection_events = Enum.reduce(catch_up_results, 0, &(&1.processed_events + &2))

    report = %{
      batch_size: batch_size,
      catch_up_ms: Float.round(catch_up_us / 1_000, 2),
      catch_up_projection_events_per_second: throughput(catch_up_projection_events, catch_up_us),
      catch_up_source_events: incremental_count,
      catch_up_source_events_per_second: throughput(incremental_count, catch_up_us),
      events_per_trace: Keyword.fetch!(opts, :events_per_trace),
      payload_bytes: Keyword.fetch!(opts, :payload_bytes),
      replay_ms: Float.round(replay_us / 1_000, 2),
      replay_projection_events_per_second: throughput(replay_projection_events, replay_us),
      replay_source_events: baseline_count,
      replay_source_events_per_second: throughput(baseline_count, replay_us),
      tenant_id: tenant_id,
      total_projection_events: replay_projection_events + catch_up_projection_events,
      total_source_events: baseline_count + incremental_count,
      traces: Keyword.fetch!(opts, :traces)
    }

    IO.puts("""
    DecisionGraph.Projector benchmark
    tenant_id: #{report.tenant_id}
    traces: #{report.traces}
    events_per_trace: #{report.events_per_trace}
    total_source_events: #{report.total_source_events}
    payload_bytes: #{report.payload_bytes}
    batch_size: #{report.batch_size}
    replay_source_events: #{report.replay_source_events}
    replay_ms: #{report.replay_ms}
    replay_source_events_per_second: #{report.replay_source_events_per_second}
    replay_projection_events_per_second: #{report.replay_projection_events_per_second}
    catch_up_source_events: #{report.catch_up_source_events}
    catch_up_ms: #{report.catch_up_ms}
    catch_up_source_events_per_second: #{report.catch_up_source_events_per_second}
    catch_up_projection_events_per_second: #{report.catch_up_projection_events_per_second}
    total_projection_events: #{report.total_projection_events}
    """)
  end

  defp parse_args!(args) do
    {opts, _argv, invalid} =
      OptionParser.parse(args,
        strict: [
          batch_size: :integer,
          events_per_trace: :integer,
          payload_bytes: :integer,
          tenant_id: :string,
          traces: :integer
        ]
      )

    if invalid != [] do
      raise ArgumentError, "Unsupported benchmark options: #{inspect(invalid)}"
    end

    traces = positive_integer!(Keyword.get(opts, :traces, @default_traces), "--traces")

    events_per_trace =
      positive_integer!(
        Keyword.get(opts, :events_per_trace, @default_events_per_trace),
        "--events-per-trace"
      )

    if events_per_trace < 4 do
      raise ArgumentError,
            "--events-per-trace must be at least 4 so each trace can start, evaluate policy, and finish"
    end

    [
      batch_size:
        positive_integer!(Keyword.get(opts, :batch_size, @default_batch_size), "--batch-size"),
      events_per_trace: events_per_trace,
      payload_bytes:
        non_negative_integer!(
          Keyword.get(opts, :payload_bytes, @default_payload_bytes),
          "--payload-bytes"
        ),
      tenant_id: Keyword.get(opts, :tenant_id, default_tenant_id()),
      traces: traces
    ]
  end

  defp ensure_storage_ready! do
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:postgrex)

    repo_config = Application.fetch_env!(:dg_store, Repo)

    case Postgres.storage_up(repo_config) do
      :ok -> :ok
      {:error, :already_up} -> :ok
    end

    {:ok, _} = Application.ensure_all_started(:dg_store)

    case Repo.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    {:ok, _, _} =
      Migrator.with_repo(Repo, fn repo ->
        Migrator.run(repo, Application.app_dir(:dg_store, "priv/repo/migrations"), :up, all: true)
      end)
  end

  defp build_events(prefix, run_token, traces, events_per_trace, payload_bytes) do
    Enum.flat_map(1..traces, fn trace_number ->
      trace_id = "#{prefix}-#{run_token}-bench-trace-#{trace_number}"

      Enum.map(0..(events_per_trace - 1), fn trace_seq ->
        build_event(trace_id, trace_seq, events_per_trace, payload_bytes)
      end)
    end)
  end

  defp build_event(trace_id, 0, _events_per_trace, payload_bytes) do
    EventEnvelope.new(%{
      actor: %{actor_id: "projector-bench", actor_type: "agent"},
      event_id: "#{trace_id}-trace_started-0",
      event_type: "TraceStarted",
      idempotency_key: "start:#{trace_id}",
      occurred_at: occurred_at(0),
      payload: %{
        "padding" => padding(payload_bytes),
        "primary_entity" => %{
          "entity_id" => "entity:#{trace_id}",
          "entity_type" => "account",
          "system" => "crm"
        },
        "title" => "Benchmark trace #{trace_id}",
        "workflow" => "projector_benchmark"
      },
      source: %{producer_id: "projector-bench", subsystem: "phase4", system: "bench"},
      trace_id: trace_id,
      trace_seq: 0
    })
  end

  defp build_event(trace_id, trace_seq, events_per_trace, payload_bytes)
       when trace_seq == events_per_trace - 1 do
    EventEnvelope.new(%{
      actor: %{actor_id: "projector-bench", actor_type: "agent"},
      event_id: "#{trace_id}-trace_finished-#{trace_seq}",
      event_type: "TraceFinished",
      idempotency_key: "finish:#{trace_id}",
      occurred_at: occurred_at(trace_seq),
      payload: %{
        "outcome" => "success",
        "padding" => padding(payload_bytes),
        "summary" => "Finished #{trace_id}"
      },
      source: %{producer_id: "projector-bench", subsystem: "phase4", system: "bench"},
      trace_id: trace_id,
      trace_seq: trace_seq
    })
  end

  defp build_event(trace_id, 1, _events_per_trace, payload_bytes) do
    EventEnvelope.new(%{
      actor: %{actor_id: "projector-bench", actor_type: "agent"},
      causation_event_id: "#{trace_id}-trace_started-0",
      event_id: "#{trace_id}-input_observed-1",
      event_type: "InputObserved",
      idempotency_key: "input:#{trace_id}:1",
      occurred_at: occurred_at(1),
      payload: %{
        "facts" => [
          %{
            "as_of" => occurred_at(1),
            "key" => "padding",
            "value" => %{"type" => "string", "value" => padding(payload_bytes)}
          }
        ],
        "input_id" => "input:#{trace_id}:1",
        "source" => %{
          "object_id" => "object:#{trace_id}",
          "object_type" => "account",
          "system" => "crm"
        }
      },
      source: %{producer_id: "projector-bench", subsystem: "phase4", system: "bench"},
      trace_id: trace_id,
      trace_seq: 1
    })
  end

  defp build_event(trace_id, 2, _events_per_trace, payload_bytes) do
    EventEnvelope.new(%{
      actor: %{actor_id: "projector-bench", actor_type: "agent"},
      causation_event_id: "#{trace_id}-input_observed-1",
      event_id: "#{trace_id}-policy_evaluated-2",
      event_type: "PolicyEvaluated",
      idempotency_key: "policy:#{trace_id}:2",
      occurred_at: occurred_at(2),
      payload: %{
        "decision" => "allow",
        "explanation" => %{"summary" => padding(payload_bytes)},
        "inputs" => ["input:#{trace_id}:1"],
        "policy" => %{"policy_id" => "bench_guard", "policy_version" => "1.0"},
        "violations" => []
      },
      source: %{producer_id: "projector-bench", subsystem: "phase4", system: "bench"},
      trace_id: trace_id,
      trace_seq: 2
    })
  end

  defp build_event(trace_id, trace_seq, _events_per_trace, payload_bytes) do
    EventEnvelope.new(%{
      actor: %{actor_id: "projector-bench", actor_type: "agent"},
      causation_event_id: "#{trace_id}-policy_evaluated-2",
      event_id: "#{trace_id}-action_proposed-#{trace_seq}",
      event_type: "ActionProposed",
      idempotency_key: "action:#{trace_id}:#{trace_seq}",
      occurred_at: occurred_at(trace_seq),
      payload: %{
        "action_id" => "action:#{trace_id}:#{trace_seq}",
        "action_type" => "update",
        "changes" => [
          %{
            "new_value" => %{"type" => "string", "value" => padding(payload_bytes)},
            "old_value" => %{"type" => "string", "value" => ""},
            "path" => "status"
          }
        ],
        "target_entity" => %{
          "entity_id" => "entity:#{trace_id}",
          "entity_type" => "account",
          "system" => "crm"
        },
        "target_system" => "crm"
      },
      source: %{producer_id: "projector-bench", subsystem: "phase4", system: "bench"},
      trace_id: trace_id,
      trace_seq: trace_seq
    })
  end

  defp occurred_at(trace_seq) do
    second =
      trace_seq
      |> rem(60)
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    "2025-12-31T16:00:#{second}Z"
  end

  defp default_tenant_id do
    "projector-bench:" <> Integer.to_string(System.system_time(:millisecond))
  end

  defp benchmark_run_token(tenant_id) do
    tenant_id
    |> String.replace(~r/[^A-Za-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp padding(bytes) when bytes <= 0, do: ""
  defp padding(bytes), do: String.duplicate("x", bytes)

  defp positive_integer!(value, _flag) when is_integer(value) and value > 0, do: value

  defp positive_integer!(value, flag),
    do: raise(ArgumentError, "#{flag} must be a positive integer, got: #{inspect(value)}")

  defp non_negative_integer!(value, _flag) when is_integer(value) and value >= 0, do: value

  defp non_negative_integer!(value, flag),
    do: raise(ArgumentError, "#{flag} must be a non-negative integer, got: #{inspect(value)}")

  defp throughput(_count, 0), do: 0.0

  defp throughput(count, microseconds) do
    count
    |> Kernel./(microseconds / 1_000_000)
    |> Float.round(2)
  end
end
