defmodule DecisionGraph.Domain.RuntimeContextTest do
  use ExUnit.Case, async: true

  alias DecisionGraph.Domain.RuntimeContext

  test "builds logger metadata without nil values" do
    context =
      RuntimeContext.new(
        request_id: "req-123",
        tenant_id: "tenant-a",
        trace_id: nil
      )

    assert RuntimeContext.logger_metadata(context) == [
             request_id: "req-123",
             tenant_id: "tenant-a"
           ]
  end
end
