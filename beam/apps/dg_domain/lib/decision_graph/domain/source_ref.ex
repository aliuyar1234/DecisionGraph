defmodule DecisionGraph.Domain.SourceRef do
  @moduledoc "Source metadata attached to ingested events."

  @enforce_keys [:producer_id, :system]
  @derive {Jason.Encoder, only: [:producer_id, :subsystem, :system]}
  defstruct [:producer_id, :subsystem, :system]

  @type t :: %__MODULE__{
          producer_id: String.t(),
          subsystem: String.t() | nil,
          system: String.t()
        }

  @spec new(map() | keyword()) :: t()
  def new(attrs) do
    attrs = Map.new(attrs)

    %__MODULE__{
      producer_id: attrs |> fetch!(:producer_id) |> normalize_required!(:producer_id),
      subsystem: attrs |> fetch_optional(:subsystem) |> normalize_optional(),
      system: attrs |> fetch!(:system) |> normalize_required!(:system)
    }
  end

  defp fetch!(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.fetch!(attrs, Atom.to_string(key))
    end
  end

  defp fetch_optional(attrs, key) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))
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

  defp normalize_optional(nil), do: nil
  defp normalize_optional(value) when is_binary(value), do: String.trim(value)
  defp normalize_optional(value), do: value |> to_string() |> normalize_optional()
end
