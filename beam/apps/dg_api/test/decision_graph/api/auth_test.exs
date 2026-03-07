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

  test "supports rotated tokens via tokens list" do
    original_accounts = Application.get_env(:dg_api, :service_accounts, [])

    Application.put_env(:dg_api, :service_accounts, [
      %{
        account_id: "reader-rotating",
        permissions: [],
        roles: ["reader"],
        tenant_ids: ["tenant-a"],
        tokens: ["reader-old-token", "reader-new-token"]
      }
    ])

    on_exit(fn -> Application.put_env(:dg_api, :service_accounts, original_accounts) end)

    assert {:ok, old_account} =
             Auth.authenticate("Bearer reader-old-token", "tenant-a", ["reader"])

    assert {:ok, new_account} =
             Auth.authenticate("Bearer reader-new-token", "tenant-a", ["reader"])

    assert old_account.account_id == "reader-rotating"
    assert new_account.account_id == "reader-rotating"
  end
end
