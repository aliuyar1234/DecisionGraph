defmodule DecisionGraph.Projector.Support do
  @moduledoc false

  alias DecisionGraph.Error

  @projection_names [:context_graph, :trace_summary, :precedent_index]

  @spec projection_names() :: [atom()]
  def projection_names, do: @projection_names

  @spec normalize_projection_name!(atom() | String.t()) :: atom()
  def normalize_projection_name!(projection_name) when projection_name in @projection_names,
    do: projection_name

  def normalize_projection_name!(projection_name) when is_binary(projection_name) do
    normalized =
      projection_name
      |> String.trim()
      |> String.to_existing_atom()

    if normalized in @projection_names do
      normalized
    else
      raise Error, code: :invalid_argument, message: "Unknown projection '#{projection_name}'"
    end
  rescue
    ArgumentError ->
      raise Error, code: :invalid_argument, message: "Unknown projection '#{projection_name}'"
  end

  @spec normalize_tenant_id(String.t() | term()) :: String.t()
  def normalize_tenant_id(tenant_id) when is_binary(tenant_id) do
    case String.trim(tenant_id) do
      "" -> raise Error, code: :invalid_argument, message: "tenant_id cannot be empty"
      normalized -> normalized
    end
  end

  def normalize_tenant_id(tenant_id), do: tenant_id |> to_string() |> normalize_tenant_id()

  @spec normalize_batch_size(term()) :: pos_integer()
  def normalize_batch_size(value) when is_integer(value) and value > 0, do: value

  def normalize_batch_size(value) do
    raise Error,
      code: :invalid_argument,
      message: "batch_size must be positive, got #{inspect(value)}"
  end

  @spec normalize_limit(term()) :: pos_integer()
  def normalize_limit(value) when is_integer(value) and value > 0 and value <= 10_000, do: value

  def normalize_limit(value) do
    raise Error,
      code: :invalid_argument,
      message: "limit must be between 1 and 10000, got #{inspect(value)}"
  end

  @spec normalize_optional_non_negative(term()) :: non_neg_integer() | nil
  def normalize_optional_non_negative(nil), do: nil
  def normalize_optional_non_negative(value) when is_integer(value) and value >= 0, do: value

  def normalize_optional_non_negative(value) do
    raise Error,
      code: :invalid_argument,
      message: "log sequence values must be non-negative, got #{inspect(value)}"
  end

  @spec fetch(map(), String.t(), term()) :: term()
  def fetch(map, key, default \\ nil) when is_map(map) do
    atom_key =
      try do
        String.to_existing_atom(key)
      rescue
        ArgumentError -> nil
      end

    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      atom_key && Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      true -> default
    end
  end

  @spec blank?(term()) :: boolean()
  def blank?(value) when is_binary(value), do: String.trim(value) == ""
  def blank?(value), do: is_nil(value)

  @spec decode_json_map(String.t() | nil) :: map()
  def decode_json_map(nil), do: %{}
  def decode_json_map(""), do: %{}
  def decode_json_map(value), do: Jason.decode!(value)

  @spec wrap_error(term()) :: Error.t()
  def wrap_error(%Error{} = error), do: error

  def wrap_error(error) do
    Error.new(:storage, "Projection runtime error: #{Exception.message(error)}", %{
      exception: inspect(error.__struct__)
    })
  end
end
