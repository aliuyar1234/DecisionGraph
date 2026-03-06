defmodule Mix.Tasks.Dg.Store.Bench do
  @shortdoc "Benchmarks DecisionGraph.Store append and batch-read throughput"

  use Mix.Task

  alias DecisionGraph.Domain.EventEnvelope
  alias DecisionGraph.Store
  alias DecisionGraph.Store.Repo
  alias Ecto.Adapters.Postgres
  alias Ecto.Migrator

  @requirements ["loadpaths"]
  @default_batch_size 250
  @default_events_per_trace 8
  @default_payload_bytes 512
  @default_traces 100

  @impl true
  def run(args) do
    opts = parse_args!(args)
    tenant_id = Keyword.fetch!(opts, :tenant_id)

    ensure_storage_ready!()
    :ok = Store.clear(tenant_id: tenant_id)

    events =
      build_events(
        Keyword.fetch!(opts, :traces),
        Keyword.fetch!(opts, :events_per_trace),
        Keyword.fetch!(opts, :payload_bytes)
      )

    {append_us, stored_count} =
      :timer.tc(fn ->
        events
        |> Enum.map(&Store.append_event(&1, tenant_id: tenant_id))
        |> length()
      end)

    batch_size = Keyword.fetch!(opts, :batch_size)

    {read_us, streamed_count} =
      :timer.tc(fn ->
        Store.iter_event_batches(tenant_id: tenant_id, batch_size: batch_size)
        |> Enum.flat_map(& &1)
        |> length()
      end)

    report = %{
      append_events_per_second: throughput(stored_count, append_us),
      append_ms: Float.round(append_us / 1_000, 2),
      batch_read_events_per_second: throughput(streamed_count, read_us),
      batch_read_ms: Float.round(read_us / 1_000, 2),
      batch_size: batch_size,
      events_per_trace: Keyword.fetch!(opts, :events_per_trace),
      payload_bytes: Keyword.fetch!(opts, :payload_bytes),
      tenant_id: tenant_id,
      total_events: stored_count,
      traces: Keyword.fetch!(opts, :traces)
    }

    IO.puts("""
    DecisionGraph.Store benchmark
    tenant_id: #{report.tenant_id}
    traces: #{report.traces}
    events_per_trace: #{report.events_per_trace}
    total_events: #{report.total_events}
    payload_bytes: #{report.payload_bytes}
    batch_size: #{report.batch_size}
    append_ms: #{report.append_ms}
    append_events_per_second: #{report.append_events_per_second}
    batch_read_ms: #{report.batch_read_ms}
    batch_read_events_per_second: #{report.batch_read_events_per_second}
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

    if events_per_trace < 2 do
      raise ArgumentError,
            "--events-per-trace must be at least 2 so each trace can start and finish"
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

  defp build_events(traces, events_per_trace, payload_bytes) do
    Enum.flat_map(1..traces, fn trace_number ->
      trace_id = "bench-trace-#{trace_number}"

      Enum.map(0..(events_per_trace - 1), fn trace_seq ->
        build_event(trace_id, trace_seq, events_per_trace, payload_bytes)
      end)
    end)
  end

  defp build_event(trace_id, 0, _events_per_trace, payload_bytes) do
    EventEnvelope.new(%{
      actor: %{actor_id: "bench-agent", actor_type: "agent"},
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
        "workflow" => "store_benchmark"
      },
      source: %{producer_id: "bench-producer", subsystem: "phase3", system: "bench"},
      trace_id: trace_id,
      trace_seq: 0
    })
  end

  defp build_event(trace_id, trace_seq, events_per_trace, payload_bytes)
       when trace_seq == events_per_trace - 1 do
    EventEnvelope.new(%{
      actor: %{actor_id: "bench-agent", actor_type: "agent"},
      event_id: "#{trace_id}-trace_finished-#{trace_seq}",
      event_type: "TraceFinished",
      idempotency_key: "finish:#{trace_id}",
      occurred_at: occurred_at(trace_seq),
      payload: %{
        "outcome" => "success",
        "padding" => padding(payload_bytes),
        "summary" => "Finished #{trace_id}"
      },
      source: %{producer_id: "bench-producer", subsystem: "phase3", system: "bench"},
      trace_id: trace_id,
      trace_seq: trace_seq
    })
  end

  defp build_event(trace_id, trace_seq, _events_per_trace, payload_bytes) do
    EventEnvelope.new(%{
      actor: %{actor_id: "bench-agent", actor_type: "agent"},
      causation_event_id: "#{trace_id}-input_observed-#{trace_seq - 1}",
      event_id: "#{trace_id}-input_observed-#{trace_seq}",
      event_type: "InputObserved",
      idempotency_key: "input:#{trace_id}:#{trace_seq}",
      occurred_at: occurred_at(trace_seq),
      payload: %{
        "facts" => [
          %{
            "as_of" => occurred_at(trace_seq),
            "key" => "padding",
            "value" => %{"type" => "string", "value" => padding(payload_bytes)}
          }
        ],
        "input_id" => "input:#{trace_id}:#{trace_seq}",
        "source" => %{
          "object_id" => "object:#{trace_id}",
          "object_type" => "account",
          "system" => "crm"
        }
      },
      source: %{producer_id: "bench-producer", subsystem: "phase3", system: "bench"},
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

    "2025-12-31T12:00:#{second}Z"
  end

  defp default_tenant_id do
    "bench:" <> Integer.to_string(System.system_time(:millisecond))
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
