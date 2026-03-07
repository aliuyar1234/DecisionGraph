defmodule DecisionGraph.Api.ServiceAccount do
  @moduledoc false

  @enforce_keys [:account_id, :roles, :tenant_ids, :token]
  defstruct [:account_id, :roles, :tenant_ids, :token, permissions: [], tokens: []]

  @type t :: %__MODULE__{
          account_id: String.t(),
          permissions: [String.t()],
          roles: [String.t()],
          tenant_ids: [String.t()],
          token: String.t(),
          tokens: [String.t()]
        }

  @spec new(map() | keyword()) :: t()
  def new(attrs) do
    attrs = Map.new(attrs)
    tokens = tokens(attrs)
    primary_token = List.first(tokens)

    %__MODULE__{
      account_id: required(attrs, :account_id),
      permissions: list(attrs, :permissions),
      roles: list(attrs, :roles),
      tenant_ids: list(attrs, :tenant_ids),
      token: primary_token,
      tokens: tokens
    }
  end

  @spec allows?(t(), String.t()) :: boolean()
  def allows?(%__MODULE__{permissions: permissions}, permission) do
    "*" in permissions or permission in permissions
  end

  @spec matches_token?(t(), String.t()) :: boolean()
  def matches_token?(%__MODULE__{token: token, tokens: tokens}, candidate) do
    candidate in normalized_tokens(token, tokens)
  end

  defp required(attrs, key) do
    attrs
    |> Map.get(key, Map.get(attrs, Atom.to_string(key)))
    |> case do
      nil -> raise ArgumentError, "#{key} is required"
      value -> to_string(value)
    end
  end

  defp list(attrs, key) do
    attrs
    |> Map.get(key, Map.get(attrs, Atom.to_string(key), []))
    |> List.wrap()
    |> Enum.map(&to_string/1)
  end

  defp tokens(attrs) do
    attrs
    |> Map.get(:tokens, Map.get(attrs, "tokens"))
    |> case do
      nil ->
        [required(attrs, :token)]

      values ->
        values
        |> List.wrap()
        |> Enum.map(&to_string/1)
        |> Enum.reject(&(&1 == ""))
        |> case do
          [] -> raise ArgumentError, "tokens is required"
          normalized -> normalized
        end
    end
  end

  defp normalized_tokens(token, tokens) do
    case Enum.reject(List.wrap(tokens), &is_nil/1) do
      [] -> List.wrap(token)
      configured -> configured
    end
  end
end
