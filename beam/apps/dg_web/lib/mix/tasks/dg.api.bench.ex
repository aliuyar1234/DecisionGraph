defmodule Mix.Tasks.Dg.Api.Bench do
  @shortdoc "Benchmarks DecisionGraph HTTP API latency across the core Phase 5 flows"

  use Mix.Task

  alias DecisionGraph.Domain.EventEnvelope
  alias DecisionGraph.Projector.Engine
  alias DecisionGraph.Store
  alias DecisionGraph.Store.Repo
  alias Ecto.Adapters.Postgres
  alias Ecto.Migrator
  require Logger

  @requirements ["loadpaths"]
  @default_admin_token "bench-admin-token"
  @default_event_iterations 20
  @default_payload_bytes 256
  @default_port 4103
  @default_read_iterations 30
  @default_seed_events_per_trace 6
  @default_seed_traces 40
  @default_tenant_id "bench-http"
  @default_warmup 5

  @impl true
  def run(args) do
    opts = parse_args!(args)

    ensure_non_sandbox_pool!()
    Logger.configure(level: :warning)

    configure_runtime!(opts)
    ensure_storage_ready!()
    ensure_web_runtime!(opts)
    clear_benchmark_state!(opts)
    seeded = seed_fixture_data!(opts)

    base_url = "http://127.0.0.1:#{Keyword.fetch!(opts, :port)}"

    read_trace =
      measure_flow(
        "GET /api/v1/traces/:trace_id",
        Keyword.fetch!(opts, :read_iterations),
        Keyword.fetch!(opts, :warmup),
        fn _iteration ->
          request_json!(
            :get,
            base_url <> "/api/v1/traces/" <> seeded.reference_trace_id,
            [],
            headers(Keyword.fetch!(opts, :tenant_id), "bench-reader-token")
          )
        end
      )

    health =
      measure_flow(
        "GET /api/v1/projections/health",
        Keyword.fetch!(opts, :read_iterations),
        Keyword.fetch!(opts, :warmup),
        fn _iteration ->
          request_json!(
            :get,
            base_url <> "/api/v1/projections/health",
            [],
            headers(Keyword.fetch!(opts, :tenant_id), "bench-reader-token")
          )
        end
      )

    replay =
      measure_flow(
        "POST /api/v1/admin/replays",
        Keyword.fetch!(opts, :event_iterations),
        Keyword.fetch!(opts, :warmup),
        fn iteration ->
          response =
            request_json!(
              :post,
              base_url <> "/api/v1/admin/replays",
              %{
                "metadata" => %{"benchmark_iteration" => iteration},
                "mode" => "catch_up",
                "projection" => "trace_summary",
                "reason" => "phase5 api benchmark"
              },
              headers(Keyword.fetch!(opts, :tenant_id), @default_admin_token)
            )

          response
        end,
        fn response ->
          response
          |> get_in(["data", "run", "job_id"])
          |> wait_for_replay_completion!(base_url, opts)
        end
      )

    event_write =
      measure_flow(
        "POST /api/v1/events",
        Keyword.fetch!(opts, :event_iterations),
        Keyword.fetch!(opts, :warmup),
        fn iteration ->
          request_json!(
            :post,
            base_url <> "/api/v1/events",
            build_benchmark_write_event(
              Keyword.fetch!(opts, :tenant_id),
              iteration,
              Keyword.fetch!(opts, :payload_bytes)
            ),
            headers(Keyword.fetch!(opts, :tenant_id), "bench-writer-token")
          )
        end
      )

    report = %{
      captured_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
      dataset: %{
        payload_bytes: Keyword.fetch!(opts, :payload_bytes),
        seed_events_per_trace: Keyword.fetch!(opts, :seed_events_per_trace),
        seed_traces: Keyword.fetch!(opts, :seed_traces),
        seeded_source_events: seeded.seeded_source_events,
        tenant_id: Keyword.fetch!(opts, :tenant_id),
        write_iterations: Keyword.fetch!(opts, :event_iterations)
      },
      endpoint: base_url,
      environment: %{
        database: Repo.config()[:database],
        elixir: System.version(),
        machine: machine_label(),
        mix_env: Mix.env() |> to_string(),
        otp: System.otp_release(),
        phoenix: Application.spec(:phoenix, :vsn) |> to_string(),
        bandit: Application.spec(:bandit, :vsn) |> to_string(),
        postgres_host: Repo.config()[:hostname],
        postgres_pool_size: Repo.config()[:pool_size]
      },
      flows: %{
        "GET /api/v1/projections/health" => health,
        "GET /api/v1/traces/:trace_id" => read_trace,
        "POST /api/v1/admin/replays" => replay,
        "POST /api/v1/events" => event_write
      }
    }

    maybe_write_report(report, Keyword.get(opts, :output))
    print_report(report)
  end

  defp parse_args!(args) do
    {opts, _argv, invalid} =
      OptionParser.parse(args,
        strict: [
          event_iterations: :integer,
          output: :string,
          payload_bytes: :integer,
          port: :integer,
          read_iterations: :integer,
          seed_events_per_trace: :integer,
          seed_traces: :integer,
          tenant_id: :string,
          warmup: :integer
        ]
      )

    if invalid != [] do
      raise ArgumentError, "Unsupported benchmark options: #{inspect(invalid)}"
    end

    [
      event_iterations:
        positive_integer!(
          Keyword.get(opts, :event_iterations, @default_event_iterations),
          "--event-iterations"
        ),
      output: Keyword.get(opts, :output),
      payload_bytes:
        non_negative_integer!(
          Keyword.get(opts, :payload_bytes, @default_payload_bytes),
          "--payload-bytes"
        ),
      port: positive_integer!(Keyword.get(opts, :port, @default_port), "--port"),
      read_iterations:
        positive_integer!(
          Keyword.get(opts, :read_iterations, @default_read_iterations),
          "--read-iterations"
        ),
      seed_events_per_trace:
        positive_integer!(
          Keyword.get(opts, :seed_events_per_trace, @default_seed_events_per_trace),
          "--seed-events-per-trace"
        ),
      seed_traces:
        positive_integer!(Keyword.get(opts, :seed_traces, @default_seed_traces), "--seed-traces"),
      tenant_id: Keyword.get(opts, :tenant_id, @default_tenant_id),
      warmup: positive_integer!(Keyword.get(opts, :warmup, @default_warmup), "--warmup")
    ]
  end

  defp configure_runtime!(opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)

    Application.put_env(:dg_api, :rate_limits, %{admin: 10_000, read: 10_000, write: 10_000})

    Application.put_env(:dg_api, :service_accounts, [
      %{
        account_id: "bench-reader",
        permissions: [],
        roles: ["reader"],
        tenant_ids: [tenant_id],
        token: "bench-reader-token"
      },
      %{
        account_id: "bench-writer",
        permissions: [],
        roles: ["writer"],
        tenant_ids: [tenant_id],
        token: "bench-writer-token"
      },
      %{
        account_id: "bench-admin",
        permissions: ["projection_rebuild", "projection_replay"],
        roles: ["admin"],
        tenant_ids: [tenant_id],
        token: @default_admin_token
      }
    ])

    endpoint_config =
      Application.get_env(:dg_web, DecisionGraphWeb.Endpoint, [])
      |> Keyword.put(:server, true)
      |> Keyword.put(:http, ip: {127, 0, 0, 1}, port: Keyword.fetch!(opts, :port))

    Application.put_env(:dg_web, DecisionGraphWeb.Endpoint, endpoint_config)
    Application.put_env(:phoenix, :serve_endpoints, true)
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

  defp ensure_web_runtime!(opts) do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)
    {:ok, _} = Application.ensure_all_started(:dg_web)

    case Process.whereis(DecisionGraphWeb.Endpoint) do
      nil ->
        {:ok, _pid} = DecisionGraphWeb.Endpoint.start_link()

      _pid ->
        :ok
    end

    wait_for_http_ready!("http://127.0.0.1:#{Keyword.fetch!(opts, :port)}/api/healthz")
  end

  defp clear_benchmark_state!(opts) do
    clear_rate_limiter!()
    :ok = Store.clear(tenant_id: Keyword.fetch!(opts, :tenant_id))
  end

  defp seed_fixture_data!(opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)
    payload_bytes = Keyword.fetch!(opts, :payload_bytes)
    seed_events_per_trace = Keyword.fetch!(opts, :seed_events_per_trace)
    seed_traces = Keyword.fetch!(opts, :seed_traces)

    run_token =
      "#{tenant_id}-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"

    events = build_seed_events(run_token, seed_traces, seed_events_per_trace, payload_bytes)

    Enum.each(events, fn envelope ->
      Store.append_event(envelope, tenant_id: tenant_id)
    end)

    {:ok, _results} = Engine.rebuild_all(tenant_id: tenant_id, batch_size: 250)
    wait_for_current_projections!(tenant_id)

    %{
      reference_trace_id: "seed-#{run_token}-trace-#{seed_traces}",
      seeded_source_events: length(events)
    }
  end

  defp build_seed_events(run_token, seed_traces, seed_events_per_trace, payload_bytes) do
    Enum.flat_map(1..seed_traces, fn trace_number ->
      trace_id = "seed-#{run_token}-trace-#{trace_number}"

      Enum.map(0..(seed_events_per_trace - 1), fn trace_seq ->
        build_seed_event(trace_id, trace_seq, seed_events_per_trace, payload_bytes)
      end)
    end)
  end

  defp build_seed_event(trace_id, 0, _seed_events_per_trace, payload_bytes) do
    EventEnvelope.new(%{
      actor: %{actor_id: "api-bench", actor_type: "agent"},
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
        "title" => "HTTP benchmark trace #{trace_id}",
        "workflow" => "api_benchmark"
      },
      source: %{producer_id: "api-bench", subsystem: "phase5", system: "bench"},
      trace_id: trace_id,
      trace_seq: 0
    })
  end

  defp build_seed_event(trace_id, trace_seq, seed_events_per_trace, payload_bytes)
       when trace_seq == seed_events_per_trace - 1 do
    EventEnvelope.new(%{
      actor: %{actor_id: "api-bench", actor_type: "agent"},
      causation_event_id: "#{trace_id}-policy_evaluated-2",
      event_id: "#{trace_id}-trace_finished-#{trace_seq}",
      event_type: "TraceFinished",
      idempotency_key: "finish:#{trace_id}",
      occurred_at: occurred_at(trace_seq),
      payload: %{
        "outcome" => "success",
        "padding" => padding(payload_bytes),
        "summary" => "Completed #{trace_id}"
      },
      source: %{producer_id: "api-bench", subsystem: "phase5", system: "bench"},
      trace_id: trace_id,
      trace_seq: trace_seq
    })
  end

  defp build_seed_event(trace_id, 1, _seed_events_per_trace, payload_bytes) do
    EventEnvelope.new(%{
      actor: %{actor_id: "api-bench", actor_type: "agent"},
      causation_event_id: "#{trace_id}-trace_started-0",
      event_id: "#{trace_id}-input_observed-1",
      event_type: "InputObserved",
      idempotency_key: "input:#{trace_id}:1",
      occurred_at: occurred_at(1),
      payload: %{
        "facts" => [
          %{
            "as_of" => occurred_at(1),
            "key" => "benchmark_payload",
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
      source: %{producer_id: "api-bench", subsystem: "phase5", system: "bench"},
      trace_id: trace_id,
      trace_seq: 1
    })
  end

  defp build_seed_event(trace_id, 2, _seed_events_per_trace, payload_bytes) do
    EventEnvelope.new(%{
      actor: %{actor_id: "api-bench", actor_type: "agent"},
      causation_event_id: "#{trace_id}-input_observed-1",
      event_id: "#{trace_id}-policy_evaluated-2",
      event_type: "PolicyEvaluated",
      idempotency_key: "policy:#{trace_id}:2",
      occurred_at: occurred_at(2),
      payload: %{
        "decision" => "allow",
        "explanation" => %{"summary" => padding(payload_bytes)},
        "inputs" => ["input:#{trace_id}:1"],
        "policy" => %{"policy_id" => "api_bench_guard", "policy_version" => "1.0"},
        "violations" => []
      },
      source: %{producer_id: "api-bench", subsystem: "phase5", system: "bench"},
      trace_id: trace_id,
      trace_seq: 2
    })
  end

  defp build_seed_event(trace_id, trace_seq, _seed_events_per_trace, payload_bytes) do
    EventEnvelope.new(%{
      actor: %{actor_id: "api-bench", actor_type: "agent"},
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
      source: %{producer_id: "api-bench", subsystem: "phase5", system: "bench"},
      trace_id: trace_id,
      trace_seq: trace_seq
    })
  end

  defp build_benchmark_write_event(tenant_id, iteration, payload_bytes) do
    trace_id = "http-bench-write-#{tenant_id}-#{iteration}"

    %{
      "actor" => %{"actor_id" => "api-bench", "actor_type" => "agent"},
      "event_id" => "#{trace_id}-trace_started-0",
      "event_type" => "TraceStarted",
      "idempotency_key" => "http-start:#{trace_id}",
      "occurred_at" => occurred_at(iteration + 10),
      "payload" => %{
        "padding" => padding(payload_bytes),
        "primary_entity" => %{
          "entity_id" => "entity:#{trace_id}",
          "entity_type" => "account",
          "system" => "crm"
        },
        "title" => "HTTP write benchmark #{trace_id}",
        "workflow" => "api_http_benchmark"
      },
      "source" => %{"producer_id" => "api-bench", "subsystem" => "phase5", "system" => "bench"},
      "trace_id" => trace_id,
      "trace_seq" => 0
    }
  end

  defp measure_flow(
         name,
         iterations,
         warmup,
         request_fun,
         after_each_fun \\ fn _response -> :ok end
       ) do
    Enum.each(1..warmup, fn iteration ->
      request_fun.(iteration) |> after_each_fun.()
    end)

    samples =
      Enum.map(1..iterations, fn iteration ->
        {microseconds, response} = :timer.tc(fn -> request_fun.(iteration) end)
        :ok = after_each_fun.(response)
        microseconds / 1_000
      end)

    summarize_flow(name, samples, iterations)
  end

  defp summarize_flow(name, samples, iterations) do
    total_ms = Enum.sum(samples)

    %{
      iterations: iterations,
      mean_ms: round_float(total_ms / iterations),
      p50_ms: percentile(samples, 50),
      p95_ms: percentile(samples, 95),
      throughput_rps: round_float(iterations * 1_000 / total_ms),
      warm_state: "warm",
      workflow: name
    }
  end

  defp request_json!(method, url, body, headers) do
    curl =
      System.find_executable("curl") || System.find_executable("curl.exe") ||
        raise "curl is required to run mix dg.api.bench"

    args =
      [
        "--silent",
        "--show-error",
        "--location",
        "--request",
        method |> to_string() |> String.upcase(),
        "--write-out",
        "\n__STATUS__:%{http_code}",
        url
      ] ++
        Enum.flat_map(headers, &["--header", &1]) ++
        case method do
          :get -> []
          _other -> ["--header", "content-type: application/json", "--data", Jason.encode!(body)]
        end

    case System.cmd(curl, args, stderr_to_stdout: true) do
      {output, 0} ->
        [response_body, status_text] =
          case String.split(output, "\n__STATUS__:", parts: 2) do
            [body_text, code_text] ->
              [body_text, code_text]

            _other ->
              raise "HTTP benchmark request returned an unexpected curl payload: #{output}"
          end

        status =
          status_text
          |> String.trim()
          |> String.to_integer()

        if status in [200, 201, 202] do
          Jason.decode!(response_body)
        else
          raise "HTTP benchmark request failed with status #{status}: #{response_body}"
        end

      {output, status} ->
        raise "curl request failed with exit status #{status}: #{output}"
    end
  end

  defp wait_for_replay_completion!(job_id, base_url, opts, attempts \\ 150)

  defp wait_for_replay_completion!(job_id, base_url, opts, attempts) when attempts > 0 do
    response =
      request_json!(
        :get,
        base_url <> "/api/v1/admin/replays/" <> job_id,
        [],
        headers(Keyword.fetch!(opts, :tenant_id), @default_admin_token)
      )

    case get_in(response, ["data", "run", "status"]) do
      status when status in ["completed", "failed", "cancelled"] ->
        :ok

      _other ->
        Process.sleep(20)
        wait_for_replay_completion!(job_id, base_url, opts, attempts - 1)
    end
  end

  defp wait_for_replay_completion!(job_id, _base_url, _opts, 0) do
    raise "Timed out waiting for replay job #{job_id} to settle"
  end

  defp wait_for_http_ready!(url, attempts \\ 120)

  defp wait_for_http_ready!(url, attempts) when attempts > 0 do
    case :httpc.request(:get, {String.to_charlist(url), []}, [timeout: 1_000],
           body_format: :binary
         ) do
      {:ok, {{_version, 200, _reason}, _headers, _body}} ->
        :ok

      _other ->
        Process.sleep(50)
        wait_for_http_ready!(url, attempts - 1)
    end
  end

  defp wait_for_http_ready!(_url, 0) do
    raise "DecisionGraphWeb endpoint did not become ready in time"
  end

  defp wait_for_current_projections!(tenant_id, attempts \\ 150)

  defp wait_for_current_projections!(tenant_id, attempts) when attempts > 0 do
    health = DecisionGraph.Projector.projection_health(tenant_id: tenant_id)

    if Enum.all?(health.projections, &(&1.pending_events == 0 and &1.is_stale == false)) do
      :ok
    else
      Process.sleep(20)
      wait_for_current_projections!(tenant_id, attempts - 1)
    end
  end

  defp wait_for_current_projections!(_tenant_id, 0) do
    raise "Timed out waiting for projections to become current"
  end

  defp maybe_write_report(_report, nil), do: :ok

  defp maybe_write_report(report, output_path) do
    output_path |> Path.dirname() |> File.mkdir_p!()
    File.write!(output_path, Jason.encode_to_iodata!(report, pretty: true))
  end

  defp print_report(report) do
    IO.puts("""
    DecisionGraph.Api benchmark
    mix_env: #{report.environment.mix_env}
    endpoint: #{report.endpoint}
    machine: #{report.environment.machine}
    database: #{report.environment.database}
    seed_traces: #{report.dataset.seed_traces}
    seed_events_per_trace: #{report.dataset.seed_events_per_trace}
    seeded_source_events: #{report.dataset.seeded_source_events}
    payload_bytes: #{report.dataset.payload_bytes}

    GET /api/v1/traces/:trace_id
      p50_ms: #{report.flows["GET /api/v1/traces/:trace_id"].p50_ms}
      p95_ms: #{report.flows["GET /api/v1/traces/:trace_id"].p95_ms}
      throughput_rps: #{report.flows["GET /api/v1/traces/:trace_id"].throughput_rps}

    GET /api/v1/projections/health
      p50_ms: #{report.flows["GET /api/v1/projections/health"].p50_ms}
      p95_ms: #{report.flows["GET /api/v1/projections/health"].p95_ms}
      throughput_rps: #{report.flows["GET /api/v1/projections/health"].throughput_rps}

    POST /api/v1/admin/replays
      p50_ms: #{report.flows["POST /api/v1/admin/replays"].p50_ms}
      p95_ms: #{report.flows["POST /api/v1/admin/replays"].p95_ms}
      throughput_rps: #{report.flows["POST /api/v1/admin/replays"].throughput_rps}

    POST /api/v1/events
      p50_ms: #{report.flows["POST /api/v1/events"].p50_ms}
      p95_ms: #{report.flows["POST /api/v1/events"].p95_ms}
      throughput_rps: #{report.flows["POST /api/v1/events"].throughput_rps}
    """)
  end

  defp headers(tenant_id, token) do
    [
      "accept: application/json",
      "authorization: Bearer " <> token,
      "x-tenant-id: " <> tenant_id
    ]
  end

  defp clear_rate_limiter! do
    case :ets.whereis(:decision_graph_api_rate_limiter) do
      :undefined -> :ok
      table -> :ets.delete_all_objects(table)
    end
  end

  defp percentile(samples, percentile_rank) do
    samples
    |> Enum.sort()
    |> then(fn sorted ->
      index =
        sorted
        |> length()
        |> Kernel.*(percentile_rank / 100)
        |> Float.ceil()
        |> trunc()
        |> max(1)
        |> Kernel.-(1)

      Enum.at(sorted, index)
    end)
    |> round_float()
  end

  defp round_float(value), do: Float.round(value * 1.0, 2)

  defp padding(0), do: ""
  defp padding(bytes), do: String.duplicate("x", bytes)

  defp occurred_at(offset_seconds) do
    base = ~U[2025-03-01 12:00:00Z]
    base |> DateTime.add(offset_seconds, :second) |> DateTime.to_iso8601()
  end

  defp machine_label do
    case :os.type() do
      {family, name} -> "#{family}/#{name}"
      other -> inspect(other)
    end
  end

  defp ensure_non_sandbox_pool! do
    case Repo.config()[:pool] do
      Ecto.Adapters.SQL.Sandbox ->
        raise """
        mix dg.api.bench requires a non-sandbox repo pool because it drives real HTTP requests.
        Run it with MIX_ENV=dev (or another non-test environment) after starting local Postgres.
        """

      _other ->
        :ok
    end
  end

  defp positive_integer!(value, _flag) when is_integer(value) and value > 0, do: value

  defp positive_integer!(value, flag) do
    raise ArgumentError, "#{flag} must be a positive integer, got: #{inspect(value)}"
  end

  defp non_negative_integer!(value, _flag) when is_integer(value) and value >= 0, do: value

  defp non_negative_integer!(value, flag) do
    raise ArgumentError, "#{flag} must be a non-negative integer, got: #{inspect(value)}"
  end
end
