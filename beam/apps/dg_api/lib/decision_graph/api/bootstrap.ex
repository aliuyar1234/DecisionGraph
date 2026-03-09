defmodule DecisionGraph.Api.Bootstrap do
  @moduledoc false

  alias DecisionGraph.Api.ServiceAccount

  @admin_permissions [
    "projection_rebuild",
    "projection_replay",
    "workflow_assign",
    "workflow_escalate",
    "workflow_export",
    "workflow_override",
    "workflow_review"
  ]

  @default_tenant_id "default"

  @spec status_snapshot() :: map()
  def status_snapshot do
    accounts = configured_accounts()

    %{
      bootstrap_source: Application.get_env(:dg_api, :bootstrap_source, "application_env"),
      configured_account_count: length(accounts),
      operator_console_account_id: Application.get_env(:dg_api, :operator_console_account_id),
      service_accounts: Enum.map(accounts, &account_summary/1)
    }
  end

  @spec generate_preview(keyword()) :: map()
  def generate_preview(opts \\ []) do
    payload = payload_for(opts)

    %{
      env: %{
        "DECISION_GRAPH_OPERATOR_ACCOUNT_ID" => payload["operator_console_account_id"],
        "DECISION_GRAPH_SERVICE_ACCOUNTS_FILE" => "/absolute/path/to/service-accounts.json"
      },
      json: payload_to_json(payload),
      payload: payload
    }
  end

  @spec rotate_preview(String.t()) :: {:ok, map()} | {:error, String.t()}
  def rotate_preview(account_id) when is_binary(account_id) do
    case Enum.find(configured_accounts(), &(&1.account_id == String.trim(account_id))) do
      nil ->
        {:error, "Select a configured account to preview a rotated token set."}

      %ServiceAccount{} = account ->
        rotated_tokens =
          (account.tokens ++ [generate_token()])
          |> Enum.uniq()

        rotated_account = %{
          "account_id" => account.account_id,
          "permissions" => account.permissions,
          "roles" => account.roles,
          "tenant_ids" => account.tenant_ids,
          "tokens" => rotated_tokens
        }

        {:ok,
         %{
           json: payload_to_json(rotated_account),
           notes: [
             "Keep old and new tokens together during the overlap window.",
             "Update clients first, then remove the retired token from the bootstrap file.",
             "Restart the runtime or reload config after applying the updated bootstrap file."
           ],
           rotated_account: rotated_account
         }}
    end
  end

  @spec configured_account_ids() :: [String.t()]
  def configured_account_ids do
    configured_accounts()
    |> Enum.map(& &1.account_id)
  end

  defp payload_for(opts) do
    tenant_ids =
      [normalize_required_string(Keyword.get(opts, :tenant_id, @default_tenant_id), :tenant_id)]
      |> maybe_include_release_demo(Keyword.get(opts, :include_release_demo, false))
      |> Enum.uniq()

    prefix =
      normalize_required_string(Keyword.get(opts, :account_prefix, "main"), :account_prefix)

    %{
      "generated_at" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
      "operator_console_account_id" => "admin-#{prefix}",
      "service_accounts" => [
        %{
          "account_id" => "reader-#{prefix}",
          "permissions" => [],
          "roles" => ["reader"],
          "tenant_ids" => tenant_ids,
          "tokens" => [generate_token()]
        },
        %{
          "account_id" => "writer-#{prefix}",
          "permissions" => ["workflow_assign", "workflow_review"],
          "roles" => ["writer"],
          "tenant_ids" => tenant_ids,
          "tokens" => [generate_token()]
        },
        %{
          "account_id" => "admin-#{prefix}",
          "permissions" => @admin_permissions,
          "roles" => ["admin"],
          "tenant_ids" => tenant_ids,
          "tokens" => [generate_token()]
        }
      ]
    }
  end

  defp configured_accounts do
    Application.get_env(:dg_api, :service_accounts, [])
    |> Enum.map(&ServiceAccount.new/1)
  end

  defp account_summary(%ServiceAccount{} = account) do
    %{
      account_id: account.account_id,
      permissions: account.permissions,
      roles: account.roles,
      tenant_ids: account.tenant_ids,
      token_count: length(account.tokens)
    }
  end

  defp maybe_include_release_demo(tenant_ids, true), do: tenant_ids ++ ["release-demo"]
  defp maybe_include_release_demo(tenant_ids, false), do: tenant_ids

  defp normalize_required_string(value, field) when is_binary(value) do
    case String.trim(value) do
      "" -> raise ArgumentError, "#{field} is required"
      normalized -> normalized
    end
  end

  defp normalize_required_string(nil, field), do: raise(ArgumentError, "#{field} is required")

  defp normalize_required_string(value, field) do
    value
    |> to_string()
    |> normalize_required_string(field)
  end

  defp generate_token do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp payload_to_json(payload),
    do: payload |> Jason.encode_to_iodata!(pretty: true) |> IO.iodata_to_binary()
end
