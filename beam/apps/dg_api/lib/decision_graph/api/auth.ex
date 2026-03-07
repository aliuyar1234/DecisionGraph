defmodule DecisionGraph.Api.Auth do
  @moduledoc false

  alias DecisionGraph.Api.Errors
  alias DecisionGraph.Api.HttpError
  alias DecisionGraph.Api.ServiceAccount

  @spec authenticate(String.t() | nil, String.t() | nil, [String.t()]) ::
          {:ok, ServiceAccount.t()} | {:error, HttpError.t()}
  def authenticate(authorization_header, tenant_id, allowed_roles) do
    with {:ok, tenant_id} <- normalize_tenant(tenant_id),
         {:ok, token} <- bearer_token(authorization_header),
         {:ok, account} <- lookup_account(token),
         :ok <- authorize_tenant(account, tenant_id),
         :ok <- authorize_roles(account, allowed_roles) do
      {:ok, account}
    end
  end

  defp normalize_tenant(nil),
    do: {:error, Errors.invalid_argument("x-tenant-id header is required")}

  defp normalize_tenant(tenant_id) do
    case String.trim(to_string(tenant_id)) do
      "" -> {:error, Errors.invalid_argument("x-tenant-id header is required")}
      normalized -> {:ok, normalized}
    end
  end

  defp bearer_token(nil), do: {:error, Errors.unauthorized()}

  defp bearer_token(value) do
    case String.split(to_string(value), " ", parts: 2) do
      ["Bearer", token] ->
        token = String.trim(token)

        if byte_size(token) > 0 do
          {:ok, token}
        else
          {:error, Errors.unauthorized("Authorization header must use Bearer token format")}
        end

      _ ->
        {:error, Errors.unauthorized("Authorization header must use Bearer token format")}
    end
  end

  defp lookup_account(token) do
    Application.get_env(:dg_api, :service_accounts, [])
    |> Enum.map(&ServiceAccount.new/1)
    |> Enum.find(&ServiceAccount.matches_token?(&1, token))
    |> case do
      nil -> {:error, Errors.unauthorized("Unknown service account token")}
      account -> {:ok, account}
    end
  end

  defp authorize_tenant(%ServiceAccount{tenant_ids: tenant_ids}, tenant_id) do
    if "*" in tenant_ids or tenant_id in tenant_ids do
      :ok
    else
      {:error, Errors.forbidden("Service account cannot access tenant #{tenant_id}")}
    end
  end

  defp authorize_roles(_account, []), do: :ok

  defp authorize_roles(%ServiceAccount{roles: roles}, allowed_roles) do
    if Enum.any?(roles, &(&1 in allowed_roles)) do
      :ok
    else
      {:error, Errors.forbidden("Service account lacks required role")}
    end
  end
end
