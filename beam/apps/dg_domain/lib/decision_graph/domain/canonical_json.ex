defmodule DecisionGraph.Domain.CanonicalJson do
  @moduledoc """
  Canonical JSON serialization compatible with the Python semantic reference.
  """

  alias DecisionGraph.Error

  @spec canonicalize!(term()) :: String.t()
  def canonicalize!(value), do: encode!(to_serializable(value))

  @spec compute_payload_hash!(map()) :: String.t()
  def compute_payload_hash!(payload) when is_map(payload) do
    canonical = canonicalize!(payload)
    "sha256:" <> Base.encode16(:crypto.hash(:sha256, canonical), case: :lower)
  end

  defp encode!(value)
       when is_binary(value) or is_integer(value) or is_boolean(value) or is_nil(value) do
    Jason.encode!(value)
  end

  defp encode!(value) when is_float(value) do
    raise Error,
      code: :schema_violation,
      message: "Float found while canonicalizing JSON. Use string representation for decimals."
  end

  defp encode!(value) when is_list(value) do
    "[" <> Enum.map_join(value, ",", &encode!/1) <> "]"
  end

  defp encode!(value) when is_map(value) do
    value
    |> Enum.map(fn {key, item} -> {normalize_key!(key), item} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map_join(",", fn {key, item} -> Jason.encode!(key) <> ":" <> encode!(item) end)
    |> then(&"{#{&1}}")
  end

  defp encode!(value) do
    raise Error,
      code: :invalid_argument,
      message: "Value is not JSON-serializable",
      details: %{value: inspect(value)}
  end

  defp to_serializable(%_{} = struct) do
    raise Error,
      code: :invalid_argument,
      message: "Structs are not JSON-serializable in payloads",
      details: %{struct: inspect(struct.__struct__)}
  end

  defp to_serializable(value) when is_map(value) do
    Map.new(value, fn {key, item} -> {normalize_key!(key), to_serializable(item)} end)
  end

  defp to_serializable(value) when is_list(value), do: Enum.map(value, &to_serializable/1)
  defp to_serializable(value) when is_atom(value), do: Atom.to_string(value)

  defp to_serializable(value) when is_tuple(value) do
    raise Error,
      code: :invalid_argument,
      message: "Tuples are not JSON-serializable in payloads",
      details: %{value: inspect(value)}
  end

  defp to_serializable(value), do: value

  defp normalize_key!(key) when is_binary(key), do: key
  defp normalize_key!(key) when is_atom(key), do: Atom.to_string(key)

  defp normalize_key!(key) do
    raise Error,
      code: :invalid_argument,
      message: "Map keys must be strings or atoms for canonical JSON",
      details: %{key: inspect(key)}
  end
end
