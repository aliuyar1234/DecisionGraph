defmodule DecisionGraph.Api.AdminTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias DecisionGraph.Api.Admin
  alias DecisionGraph.Api.ServiceAccount

  setup do
    previous_projector = Application.get_env(:dg_api, :projector_module)
    previous_controls = Application.get_env(:dg_api, :admin_controls)

    Application.put_env(:dg_api, :projector_module, DecisionGraph.Api.AdminProjectorFake)
    Application.put_env(:dg_api, :admin_controls, %{allow_rebuild: true, require_reason: true})

    DecisionGraph.Api.AdminProjectorFake.reset()

    on_exit(fn ->
      if previous_projector,
        do: Application.put_env(:dg_api, :projector_module, previous_projector),
        else: Application.delete_env(:dg_api, :projector_module)

      if previous_controls,
        do: Application.put_env(:dg_api, :admin_controls, previous_controls),
        else: Application.delete_env(:dg_api, :admin_controls)
    end)

    :ok
  end

  test "replay status is tenant scoped even when job ids are known" do
    DecisionGraph.Api.AdminProjectorFake.put_run(%{
      "job_id" => "job-foreign",
      "mode" => "catch_up",
      "projection_name" => "trace_summary",
      "status" => "running",
      "tenant_id" => "tenant-b"
    })

    assert {:error, error} =
             Admin.replay_status("job-foreign",
               tenant_id: "tenant-a",
               actor: admin_actor(["projection_replay"])
             )

    assert error.code == "not_found"
  end

  test "cancel replay does not cross tenant boundaries" do
    DecisionGraph.Api.AdminProjectorFake.put_run(%{
      "job_id" => "job-foreign",
      "mode" => "catch_up",
      "projection_name" => "trace_summary",
      "status" => "running",
      "tenant_id" => "tenant-b"
    })

    assert {:error, error} =
             Admin.cancel_replay("job-foreign",
               tenant_id: "tenant-a",
               actor: admin_actor(["projection_replay"]),
               request_id: "req-cross-tenant"
             )

    assert error.code == "not_found"

    assert %{"status" => "running"} =
             DecisionGraph.Api.AdminProjectorFake.replay_status("job-foreign")
  end

  test "rebuild requires explicit projection_rebuild permission" do
    assert {:error, error} =
             Admin.start_replay(
               %{
                 "mode" => "rebuild",
                 "projection" => "all",
                 "reason" => "rebuild after parity drift"
               },
               tenant_id: "tenant-a",
               actor: admin_actor(["projection_replay"]),
               request_id: "req-rebuild-blocked"
             )

    assert error.code == "forbidden"
  end

  test "rebuild respects the deployment toggle" do
    Application.put_env(:dg_api, :admin_controls, %{allow_rebuild: false, require_reason: true})

    assert {:error, error} =
             Admin.start_replay(
               %{"mode" => "rebuild", "projection" => "all", "reason" => "full rebuild"},
               tenant_id: "tenant-a",
               actor: admin_actor(["projection_rebuild"]),
               request_id: "req-rebuild-disabled"
             )

    assert error.code == "forbidden"
  end

  test "admin replay requests require a reason when configured" do
    assert {:error, error} =
             Admin.start_replay(
               %{"mode" => "catch_up", "projection" => "trace_summary"},
               tenant_id: "tenant-a",
               actor: admin_actor(["projection_replay"]),
               request_id: "req-missing-reason"
             )

    assert error.code == "invalid_argument"
  end

  test "accepted replay requests persist operator metadata and emit audit logs" do
    actor = admin_actor(["projection_replay", "projection_rebuild"])

    log =
      capture_log(fn ->
        assert {:ok, run} =
                 Admin.start_replay(
                   %{
                     "mode" => "catch_up",
                     "projection" => "trace_summary",
                     "reason" => "close projection lag",
                     "metadata" => %{"ticket" => "OPS-42"}
                   },
                   tenant_id: "tenant-a",
                   actor: actor,
                   request_id: "req-audit-1"
                 )

        stored_run = DecisionGraph.Api.AdminProjectorFake.replay_status(run["job_id"])

        assert stored_run["metadata_json"]["reason"] == "close projection lag"
        assert stored_run["metadata_json"]["request_id"] == "req-audit-1"
        assert stored_run["metadata_json"]["requested_by_account_id"] == actor.account_id
        assert stored_run["metadata_json"]["ticket"] == "OPS-42"
      end)

    assert log =~ "api_admin_start_replay_accepted"
  end

  defp admin_actor(permissions) do
    %ServiceAccount{
      account_id: "admin-operator",
      permissions: permissions,
      roles: ["admin"],
      tenant_ids: ["tenant-a"],
      token: "token"
    }
  end
end

defmodule DecisionGraph.Api.AdminProjectorFake do
  use Agent

  def reset(runs \\ %{}) do
    case start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    Agent.update(__MODULE__, fn _state -> normalize_runs(runs) end)
  end

  def projection_health(opts) do
    %{
      event_log_last_seq: 0,
      open_runs: [],
      projections: [],
      tenant_id: Keyword.fetch!(opts, :tenant_id)
    }
  end

  def replay(projection, opts), do: create_run("catch_up", projection, opts)
  def rebuild(projection, opts), do: create_run("rebuild", projection, opts)

  def replay_status(job_id) do
    Agent.get(__MODULE__, &Map.get(&1, job_id))
  end

  def cancel_replay(job_id) do
    Agent.get_and_update(__MODULE__, fn runs ->
      case Map.get(runs, job_id) do
        nil ->
          {{:error, DecisionGraph.Error.new(:not_found, "Replay job not found: #{job_id}")}, runs}

        run ->
          updated = Map.put(run, "status", "cancelled")
          {:ok, Map.put(runs, job_id, updated)}
      end
    end)
  end

  def put_run(run) do
    Agent.update(__MODULE__, &Map.put(&1, run["job_id"], run))
  end

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  defp create_run(mode, projection, opts) do
    job_id = "job-" <> Integer.to_string(System.unique_integer([:positive]))

    run = %{
      "job_id" => job_id,
      "metadata_json" => Keyword.get(opts, :metadata, %{}),
      "mode" => mode,
      "projection_name" => normalize_projection(projection),
      "status" => "queued",
      "tenant_id" => Keyword.fetch!(opts, :tenant_id)
    }

    put_run(run)
    {:ok, run}
  end

  defp normalize_projection(:all), do: "all"
  defp normalize_projection(projection), do: to_string(projection)

  defp normalize_runs(runs) do
    runs
    |> Enum.map(fn {job_id, run} -> {job_id, Map.new(run)} end)
    |> Map.new()
  end
end
