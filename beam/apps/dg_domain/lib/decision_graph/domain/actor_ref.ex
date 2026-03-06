defmodule DecisionGraph.Domain.ActorRef do
  @moduledoc "Actor reference used by delivery and runtime layers."

  @enforce_keys [:actor_id, :actor_type]
  @derive {Jason.Encoder, only: [:actor_id, :actor_type]}
  defstruct [:actor_id, :actor_type]

  @type actor_type :: String.t()
  @type t :: %__MODULE__{
          actor_id: String.t(),
          actor_type: actor_type()
        }

  @spec new(map() | keyword()) :: t()
  def new(attrs) do
    attrs = Map.new(attrs)

    %__MODULE__{
      actor_id: attrs |> fetch!(:actor_id) |> normalize_required!(:actor_id),
      actor_type: attrs |> fetch!(:actor_type) |> normalize_required!(:actor_type)
    }
  end

  defp fetch!(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.fetch!(attrs, Atom.to_string(key))
    end
  end

  defp normalize_required!(value, key) when is_binary(value) do
    value = String.trim(value)

    if value == "" do
      raise ArgumentError, "#{key} is required"
    end

    value
  end

  defp normalize_required!(value, key) when not is_nil(value) do
    value
    |> to_string()
    |> normalize_required!(key)
  end

  defp normalize_required!(_value, key), do: raise(ArgumentError, "#{key} is required")
end
