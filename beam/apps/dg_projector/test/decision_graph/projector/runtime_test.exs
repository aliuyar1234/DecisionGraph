defmodule DecisionGraph.Projector.RuntimeTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DecisionGraph.Projector.Runtime

  property "partition_for is deterministic and bounded" do
    check all(
            tenant_id <- StreamData.string(:alphanumeric, min_length: 1),
            projection <- StreamData.member_of(Runtime.projection_names())
          ) do
      partition = Runtime.partition_for(tenant_id, projection)

      assert partition == Runtime.partition_for(tenant_id, projection)
      assert partition >= 0
      assert partition < Runtime.partition_count()
    end
  end

  test "ensure_worker_started is idempotent under contention" do
    before = DynamicSupervisor.count_children(DecisionGraph.Projector.WorkerSupervisor).active

    results =
      1..24
      |> Task.async_stream(
        fn _ -> DecisionGraph.Projector.ensure_worker_started("tenant-a", :trace_summary) end,
        max_concurrency: 12,
        ordered: false
      )
      |> Enum.map(fn {:ok, {:ok, pid}} -> pid end)

    [pid | _] = results

    assert Enum.uniq(results) == [pid]

    assert DynamicSupervisor.count_children(DecisionGraph.Projector.WorkerSupervisor).active ==
             before + 1

    :ok = DynamicSupervisor.terminate_child(DecisionGraph.Projector.WorkerSupervisor, pid)
  end
end
