defmodule DecisionGraph.Api.Graph do
  @moduledoc false

  alias DecisionGraph.Api.Errors
  alias DecisionGraph.Projector
  alias DecisionGraph.Projector.{GraphEdgeCursor, GraphFilter, NodeRef}

  @spec get_context_subgraph(map(), keyword()) ::
          {:ok, map()} | {:error, DecisionGraph.Api.HttpError.t()}
  def get_context_subgraph(params, opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)

    try do
      center = node_ref(params)
      filter = graph_filter(params)
      {:ok, Projector.get_context_subgraph(center, tenant_id: tenant_id, filter: filter)}
    rescue
      error -> {:error, Errors.from_exception(error)}
    end
  end

  @spec list_node_edges(map(), keyword()) ::
          {:ok, map()} | {:error, DecisionGraph.Api.HttpError.t()}
  def list_node_edges(params, opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)

    try do
      node = node_ref(params)

      direction =
        normalize_direction(Map.get(params, "direction", Map.get(params, :direction, "both")))

      limit = normalize_integer(Map.get(params, "limit", Map.get(params, :limit)), 100)

      cursor =
        case Map.get(params, "cursor_edge_key", Map.get(params, :cursor_edge_key)) do
          nil ->
            nil

          edge_key ->
            %GraphEdgeCursor{
              direction: direction,
              edge_key: to_string(edge_key),
              log_seq:
                normalize_optional_integer(
                  Map.get(params, "cursor_log_seq", Map.get(params, :cursor_log_seq))
                )
            }
        end

      {:ok,
       Projector.list_node_edges(
         node,
         tenant_id: tenant_id,
         direction: direction,
         cursor: cursor,
         limit: limit
       )}
    rescue
      error -> {:error, Errors.from_exception(error)}
    end
  end

  defp node_ref(params) do
    %NodeRef{
      node_type: required(params, "node_type"),
      node_id: required(params, "node_id")
    }
  end

  defp graph_filter(params) do
    %GraphFilter{
      edge_types: csv_list(Map.get(params, "edge_types", Map.get(params, :edge_types))),
      max_depth: normalize_integer(Map.get(params, "max_depth", Map.get(params, :max_depth)), 1),
      max_edges:
        normalize_integer(Map.get(params, "max_edges", Map.get(params, :max_edges)), 100),
      max_nodes:
        normalize_integer(Map.get(params, "max_nodes", Map.get(params, :max_nodes)), 100),
      node_types: csv_list(Map.get(params, "node_types", Map.get(params, :node_types)))
    }
  end

  defp required(params, key) do
    value = Map.get(params, key, Map.get(params, String.to_atom(key)))

    case value do
      nil -> raise ArgumentError, "#{key} is required"
      other -> other |> to_string() |> String.trim()
    end
  rescue
    ArgumentError -> raise ArgumentError, "#{key} is required"
  end

  defp normalize_direction("incoming"), do: :incoming
  defp normalize_direction("outgoing"), do: :outgoing
  defp normalize_direction("both"), do: :both

  defp normalize_direction(direction) when direction in [:incoming, :outgoing, :both],
    do: direction

  defp normalize_direction(direction),
    do: raise(ArgumentError, "Unknown direction #{inspect(direction)}")

  defp normalize_integer(nil, default), do: default
  defp normalize_integer(value, _default) when is_integer(value), do: value
  defp normalize_integer(value, _default), do: value |> to_string() |> String.to_integer()

  defp normalize_optional_integer(nil), do: nil
  defp normalize_optional_integer(value) when is_integer(value), do: value
  defp normalize_optional_integer(value), do: value |> to_string() |> String.to_integer()

  defp csv_list(nil), do: nil
  defp csv_list(value) when is_list(value), do: Enum.map(value, &to_string/1)

  defp csv_list(value) do
    case value |> to_string() |> String.split(",", trim: true) do
      [] -> nil
      items -> items
    end
  end
end
