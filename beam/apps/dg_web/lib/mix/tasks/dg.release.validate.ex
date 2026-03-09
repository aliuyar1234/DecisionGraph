defmodule Mix.Tasks.Dg.Release.Validate do
  @shortdoc "Exercises the self-hosted BEAM release path and records validation evidence"

  use Mix.Task

  alias DecisionGraph.Api.ReleaseDemo
  alias DecisionGraph.Store.Repo
  alias Ecto.Adapters.Postgres
  alias Ecto.Migrator
  require Logger

  @requirements ["loadpaths"]
  @default_port 4105
  @default_timeout_ms 5_000
  @default_seed_mode :reset

  @impl true
  def run(args) do
    opts = parse_args!(args)

    quiet_logger!()
    ensure_non_sandbox_pool!()
    configure_endpoint!(Keyword.fetch!(opts, :port))
    ensure_storage_ready!()
    ensure_web_runtime!(Keyword.fetch!(opts, :port))
    quiet_logger!()

    seeded =
      ReleaseDemo.seed(
        tenant_id: Keyword.fetch!(opts, :tenant_id),
        reset: Keyword.fetch!(opts, :seed_mode) == :reset,
        rebuild: not Keyword.fetch!(opts, :skip_rebuild)
      )

    base_url = "http://127.0.0.1:#{Keyword.fetch!(opts, :port)}"

    checks = [
      check_healthz(base_url),
      check_console_html(base_url, seeded),
      check_projection_health(base_url, seeded),
      check_trace_read(base_url, seeded),
      check_workflow_list(base_url, seeded),
      check_workflow_export(base_url, seeded),
      check_replay_round_trip(base_url, seeded)
    ]

    report = %{
      captured_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
      checks: checks,
      endpoint: base_url,
      release_candidate: "v" <> to_string(Mix.Project.config()[:version]),
      seeded_demo: seeded,
      success?: Enum.all?(checks, &(&1["status"] == "passed")),
      topology: %{
        database: Repo.config()[:database],
        mix_env: Mix.env() |> to_string(),
        port: Keyword.fetch!(opts, :port),
        seed_mode: Keyword.fetch!(opts, :seed_mode) |> Atom.to_string(),
        skip_rebuild: Keyword.fetch!(opts, :skip_rebuild),
        tenant_id: Keyword.fetch!(opts, :tenant_id)
      }
    }

    maybe_write_report(report, Keyword.get(opts, :output))
    maybe_write_summary(report, Keyword.get(opts, :summary_output))
    maybe_write_step_summary(report)

    unless Keyword.fetch!(opts, :quiet) do
      print_report(report)
    end

    unless report.success? do
      Mix.raise("DecisionGraph self-hosted release validation failed")
    end
  end

  defp parse_args!(args) do
    {opts, _argv, invalid} =
      OptionParser.parse(args,
        strict: [
          output: :string,
          port: :integer,
          quiet: :boolean,
          seed_mode: :string,
          skip_rebuild: :boolean,
          summary_output: :string,
          tenant_id: :string
        ],
        aliases: [o: :output]
      )

    if invalid != [] do
      raise ArgumentError, "Unsupported dg.release.validate options: #{inspect(invalid)}"
    end

    [
      output: Keyword.get(opts, :output),
      port: Keyword.get(opts, :port, @default_port),
      quiet: Keyword.get(opts, :quiet, false),
      seed_mode: normalize_seed_mode(Keyword.get(opts, :seed_mode, @default_seed_mode)),
      skip_rebuild: Keyword.get(opts, :skip_rebuild, false),
      summary_output: Keyword.get(opts, :summary_output),
      tenant_id: Keyword.get(opts, :tenant_id, ReleaseDemo.default_tenant_id())
    ]
  end

  defp normalize_seed_mode(mode) when mode in [:reset, "reset"], do: :reset
  defp normalize_seed_mode(mode) when mode in [:reuse, "reuse"], do: :reuse

  defp normalize_seed_mode(mode) do
    raise ArgumentError,
          "Unsupported dg.release.validate --seed-mode #{inspect(mode)}. Expected reset or reuse."
  end

  defp configure_endpoint!(port) do
    endpoint_config =
      Application.get_env(:dg_web, DecisionGraphWeb.Endpoint, [])
      |> Keyword.put(:server, true)
      |> Keyword.put(:http, ip: {127, 0, 0, 1}, port: port)

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
    {:ok, _} = Application.ensure_all_started(:dg_projector)
    {:ok, _} = Application.ensure_all_started(:dg_api)

    case Repo.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    {:ok, _, _} =
      Migrator.with_repo(Repo, fn repo ->
        Migrator.run(repo, Application.app_dir(:dg_store, "priv/repo/migrations"), :up, all: true)
      end)
  end

  defp ensure_web_runtime!(port) do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)
    {:ok, _} = Application.ensure_all_started(:dg_web)

    case Process.whereis(DecisionGraphWeb.Endpoint) do
      nil ->
        {:ok, _pid} = DecisionGraphWeb.Endpoint.start_link()

      _pid ->
        :ok
    end

    wait_for_http_ready!("http://127.0.0.1:#{port}/api/healthz")
  end

  defp check_healthz(base_url) do
    {_status, _headers, body} = request!(:get, base_url <> "/api/healthz")
    result("healthz", "GET /api/healthz returned 200", %{"body" => body})
  end

  defp check_console_html(base_url, seeded) do
    {_status, _headers, body} = request!(:get, base_url <> seeded.console_paths.default)

    result("console_html", "Operator console route returned HTML successfully", %{
      "html_bytes" => byte_size(body),
      "path" => seeded.console_paths.default
    })
  end

  defp check_projection_health(base_url, seeded) do
    {_status, _headers, body} =
      request_json!(
        :get,
        base_url <> seeded.api_examples.projection_health_path,
        "",
        reader_headers(seeded.tenant_id)
      )

    projections = get_in(body, ["data", "projections"]) || []

    if projections != [] and
         Enum.all?(projections, fn projection ->
           projection["pending_events"] == 0 and projection["is_stale"] == false
         end) do
      result("projection_health", "Projection health is current for all seeded projections", %{
        "projection_count" => length(projections)
      })
    else
      failure("projection_health", "Projection health did not reach a fully current state")
    end
  end

  defp check_trace_read(base_url, seeded) do
    {_status, _headers, body} =
      request_json!(
        :get,
        base_url <> seeded.api_examples.selected_trace_path,
        "",
        reader_headers(seeded.tenant_id)
      )

    if get_in(body, ["data", "summary", "trace_id"]) == seeded.live_trace.trace_id and
         length(get_in(body, ["data", "events"]) || []) == seeded.live_trace.event_count do
      result("trace_read", "Selected trace API returned the seeded live trace", %{
        "trace_id" => seeded.live_trace.trace_id
      })
    else
      failure("trace_read", "Selected trace API did not return the expected seeded trace")
    end
  end

  defp check_workflow_list(base_url, seeded) do
    {_status, _headers, body} =
      request_json!(
        :get,
        base_url <> seeded.api_examples.recent_workflows_path,
        "",
        reader_headers(seeded.tenant_id)
      )

    items = get_in(body, ["data", "items"]) || []
    workflow_ids = Enum.map(items, & &1["workflow_id"])

    if seeded.live_trace.workflow_id in workflow_ids and
         seeded.review_workflow.workflow_id in workflow_ids do
      result("workflow_list", "Workflow API returned both exception and incident review items", %{
        "workflow_count" => length(items)
      })
    else
      failure("workflow_list", "Workflow API did not expose the seeded review items")
    end
  end

  defp check_workflow_export(base_url, seeded) do
    {_status, _headers, body} =
      request_json!(
        :get,
        base_url <> seeded.api_examples.export_workflow_path,
        "",
        admin_headers(seeded.tenant_id)
      )

    if get_in(body, ["data", "workflow", "workflow_id"]) == seeded.review_workflow.workflow_id do
      result("workflow_export", "Workflow export returned the seeded incident review", %{
        "workflow_id" => seeded.review_workflow.workflow_id
      })
    else
      failure("workflow_export", "Workflow export did not return the expected incident review")
    end
  end

  defp check_replay_round_trip(base_url, seeded) do
    {_status, _headers, response} =
      request_json!(
        :post,
        base_url <> "/api/v1/admin/replays",
        Jason.encode!(%{
          "metadata" => %{"source" => "phase10_release_validation"},
          "mode" => "catch_up",
          "projection" => "trace_summary",
          "reason" => "phase10 release validation"
        }),
        admin_headers(seeded.tenant_id)
      )

    job_id = get_in(response, ["data", "run", "job_id"])
    replay_status = wait_for_replay_completion!(base_url, job_id, seeded.tenant_id)

    if replay_status == "completed" do
      result("replay_round_trip", "Replay admission and completion succeeded", %{
        "job_id" => job_id
      })
    else
      failure("replay_round_trip", "Replay did not complete successfully for #{job_id}")
    end
  end

  defp wait_for_replay_completion!(base_url, job_id, tenant_id, attempts \\ 150)

  defp wait_for_replay_completion!(base_url, job_id, tenant_id, attempts) when attempts > 0 do
    {_status, _headers, body} =
      request_json!(
        :get,
        base_url <> "/api/v1/admin/replays/" <> job_id,
        "",
        admin_headers(tenant_id)
      )

    case get_in(body, ["data", "run", "status"]) do
      status when status in ["completed", "failed", "cancelled"] ->
        status

      _other ->
        Process.sleep(20)
        wait_for_replay_completion!(base_url, job_id, tenant_id, attempts - 1)
    end
  end

  defp wait_for_replay_completion!(_base_url, job_id, _tenant_id, 0) do
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

  defp request_json!(method, url, body, headers) do
    {status, response_headers, response_body} = request!(method, url, body, headers)

    if status in [200, 201, 202] do
      {status, response_headers, Jason.decode!(response_body)}
    else
      raise "HTTP #{method} #{url} failed with status #{status}: #{response_body}"
    end
  end

  defp request!(method, url, body \\ "", headers \\ [])

  defp request!(:get, url, _body, headers) do
    case :httpc.request(
           :get,
           {String.to_charlist(url), http_headers(headers)},
           http_options(),
           body_format: :binary
         ) do
      {:ok, {{_version, status, _reason}, response_headers, response_body}} ->
        {status, response_headers, response_body}

      other ->
        raise "HTTP GET request failed: #{inspect(other)}"
    end
  end

  defp request!(method, url, body, headers) when method in [:post] do
    request =
      {String.to_charlist(url), http_headers(headers), ~c"application/json",
       String.to_charlist(body)}

    case :httpc.request(method, request, http_options(), body_format: :binary) do
      {:ok, {{_version, status, _reason}, response_headers, response_body}} ->
        {status, response_headers, response_body}

      other ->
        raise "HTTP #{method} request failed: #{inspect(other)}"
    end
  end

  defp http_headers(headers) do
    Enum.map(headers, fn {key, value} ->
      {String.to_charlist(key), String.to_charlist(value)}
    end)
  end

  defp http_options, do: [timeout: @default_timeout_ms, connect_timeout: @default_timeout_ms]

  defp reader_headers(tenant_id) do
    [
      {"accept", "application/json"},
      {"authorization", "Bearer dev-reader-token"},
      {"x-tenant-id", tenant_id}
    ]
  end

  defp admin_headers(tenant_id) do
    [
      {"accept", "application/json"},
      {"authorization", "Bearer dev-admin-token"},
      {"content-type", "application/json"},
      {"x-tenant-id", tenant_id}
    ]
  end

  defp result(name, detail, metadata) do
    %{"detail" => detail, "metadata" => metadata, "name" => name, "status" => "passed"}
  end

  defp failure(name, detail) do
    %{"detail" => detail, "metadata" => %{}, "name" => name, "status" => "failed"}
  end

  defp maybe_write_report(_report, nil), do: :ok

  defp maybe_write_report(report, output_path) do
    output_path |> Path.dirname() |> File.mkdir_p!()
    File.write!(output_path, Jason.encode_to_iodata!(report, pretty: true))
  end

  defp maybe_write_summary(_report, nil), do: :ok

  defp maybe_write_summary(report, output_path) do
    output_path |> Path.dirname() |> File.mkdir_p!()
    File.write!(output_path, summary_markdown(report))
  end

  defp maybe_write_step_summary(report) do
    case System.get_env("GITHUB_STEP_SUMMARY") do
      nil ->
        :ok

      "" ->
        :ok

      step_summary_path ->
        File.write!(step_summary_path, summary_markdown(report), [:append])
    end
  end

  defp print_report(report) do
    IO.puts("""
    DecisionGraph self-hosted release validation
    release_candidate: #{report.release_candidate}
    endpoint: #{report.endpoint}
    tenant_id: #{report.topology.tenant_id}
    success?: #{report.success?}

    Checks
    #{Enum.map_join(report.checks, "\n", &"  #{&1["status"]} #{&1["name"]}: #{&1["detail"]}")}
    """)
  end

  defp summary_markdown(report) do
    checks =
      Enum.map_join(report.checks, "\n", fn check ->
        "- `#{check["status"]}` `#{check["name"]}`: #{check["detail"]}"
      end)

    """
    ## DecisionGraph release validation

    - release candidate: `#{report.release_candidate}`
    - endpoint: `#{report.endpoint}`
    - tenant id: `#{report.topology.tenant_id}`
    - seed mode: `#{report.topology.seed_mode}`
    - skip rebuild: `#{report.topology.skip_rebuild}`
    - success: `#{report.success?}`

    ### Checks

    #{checks}
    """
  end

  defp ensure_non_sandbox_pool! do
    case Repo.config()[:pool] do
      Ecto.Adapters.SQL.Sandbox ->
        raise """
        mix dg.release.validate requires a non-sandbox repo pool because it drives real HTTP requests.
        Run it with MIX_ENV=dev (or another non-test environment) after starting local Postgres.
        """

      _other ->
        :ok
    end
  end

  defp quiet_logger! do
    Application.put_env(:logger, :default_handler, level: :warning)
    Logger.configure(level: :warning)
  end
end
