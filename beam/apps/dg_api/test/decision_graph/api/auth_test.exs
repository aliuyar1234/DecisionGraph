defmodule DecisionGraph.Api.AuthTest do
  use ExUnit.Case, async: true

  alias DecisionGraph.Api.Auth

  test "authenticates a valid bearer token with tenant access" do
    assert {:ok, account} =
             Auth.authenticate("Bearer reader-test-token", "tenant-a", ["reader", "admin"])

    assert account.account_id == "reader-test"
    assert account.permissions == []
  end

  test "rejects missing tenant and malformed auth" do
    assert {:error, error} = Auth.authenticate("token", nil, ["reader"])
    assert error.code == "invalid_argument"
  end

  test "rejects insufficient role or tenant boundary crossing" do
    assert {:error, role_error} =
             Auth.authenticate("Bearer reader-test-token", "tenant-a", ["admin"])

    assert role_error.code == "forbidden"

    assert {:error, tenant_error} =
             Auth.authenticate("Bearer reader-test-token", "tenant-b", ["reader"])

    assert tenant_error.code == "forbidden"
  end
end
