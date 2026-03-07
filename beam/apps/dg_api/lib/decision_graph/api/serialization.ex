defmodule DecisionGraph.Api.Serialization do
  @moduledoc false

  @spec serialize(term()) :: term()
  def serialize(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> serialize()
  end

  def serialize(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {key, serialize(value)} end)
  end

  def serialize(list) when is_list(list), do: Enum.map(list, &serialize/1)

  def serialize(value) when is_atom(value) and not is_boolean(value) and not is_nil(value),
    do: Atom.to_string(value)

  def serialize(value), do: value
end
