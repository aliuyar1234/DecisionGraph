defmodule DecisionGraph.Api.ServiceAccount do
  @moduledoc false

  @enforce_keys [:account_id, :roles, :tenant_ids, :token]
  defstruct [:account_id, :roles, :tenant_ids, :token, permissions: []]

  @type t :: %__MODULE__{
          account_id: String.t(),
          permissions: [String.t()],
          roles: [String.t()],
          tenant_ids: [String.t()],
          token: String.t()
        }

  @spec new(map() | keyword()) :: t()
  def new(attrs) do
    attrs = Map.new(attrs)

    %__MODULE__{
      account_id: required(attrs, :account_id),
      permissions: list(attrs, :permissions),
      roles: list(attrs, :roles),
      tenant_ids: list(attrs, :tenant_ids),
      token: required(attrs, :token)
    }
  end

  @spec allows?(t(), String.t()) :: boolean()
  def allows?(%__MODULE__{permissions: permissions}, permission) do
    "*" in permissions or permission in permissions
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
end
