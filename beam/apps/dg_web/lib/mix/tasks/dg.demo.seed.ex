defmodule Mix.Tasks.Dg.Demo.Seed do
  @shortdoc "Seeds the BEAM self-hosted release demo dataset for the operator console"

  use Mix.Task

  alias DecisionGraph.Api.ReleaseDemo
  alias DecisionGraph.Store.Repo
  alias Ecto.Adapters.Postgres
  alias Ecto.Migrator
  require Logger

  @requirements ["loadpaths"]

  @impl true
  def run(args) do
    opts = parse_args!(args)

    quiet_logger!()
    ensure_storage_ready!()
    {:ok, _} = Application.ensure_all_started(:dg_api)
    {:ok, _} = Application.ensure_all_started(:dg_projector)
    quiet_logger!()

    report =
      ReleaseDemo.seed(
        tenant_id: Keyword.fetch!(opts, :tenant_id),
        reset: Keyword.fetch!(opts, :reset),
        rebuild: Keyword.fetch!(opts, :rebuild)
      )

    maybe_write_report(report, Keyword.get(opts, :output))
    print_report(report)
  end

  defp parse_args!(args) do
    {opts, _argv, invalid} =
      OptionParser.parse(args,
        strict: [
          output: :string,
          reset: :boolean,
          rebuild: :boolean,
          tenant_id: :string
        ],
        aliases: [o: :output]
      )

    if invalid != [] do
      raise ArgumentError, "Unsupported dg.demo.seed options: #{inspect(invalid)}"
    end

    [
      output: Keyword.get(opts, :output),
      rebuild: Keyword.get(opts, :rebuild, true),
      reset: Keyword.get(opts, :reset, true),
      tenant_id: Keyword.get(opts, :tenant_id, ReleaseDemo.default_tenant_id())
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

  defp maybe_write_report(_report, nil), do: :ok

  defp maybe_write_report(report, output_path) do
    output_path |> Path.dirname() |> File.mkdir_p!()
    File.write!(output_path, Jason.encode_to_iodata!(report, pretty: true))
  end

  defp print_report(report) do
    IO.puts("""
    DecisionGraph release demo seeded
    tenant_id: #{report.tenant_id}
    seed_profile: #{report.seed_profile}
    event_count: #{report.event_count}
    live_trace_id: #{report.live_trace.trace_id}
    live_workflow_id: #{report.live_trace.workflow_id}
    incident_review_workflow_id: #{report.review_workflow.workflow_id}
    open_workflows: #{report.workflow_inbox.open_count}

    Console URLs
      #{report.console_paths.default}
      #{report.console_paths.incident_review}

    API URLs
      #{report.api_examples.selected_trace_path}
      #{report.api_examples.recent_workflows_path}
      #{report.api_examples.projection_health_path}
      #{report.api_examples.export_workflow_path}
    """)
  end

  defp quiet_logger! do
    Application.put_env(:logger, :default_handler, level: :warning)
    Logger.configure(level: :warning)
  end
end
