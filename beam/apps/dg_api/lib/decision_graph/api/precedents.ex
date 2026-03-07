defmodule DecisionGraph.Api.Precedents do
  @moduledoc false

  alias DecisionGraph.Api.Errors
  alias DecisionGraph.Projector

  @spec find_precedents(map(), keyword()) ::
          {:ok, list()} | {:error, DecisionGraph.Api.HttpError.t()}
  def find_precedents(params, opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)

    try do
      query =
        params
        |> Map.take([
          "entity_id",
          "entity_type",
          "limit",
          "outcome",
          "policy_id",
          "policy_version"
        ])
        |> Enum.map(fn {key, value} ->
          {String.to_atom(key), if(key == "limit", do: normalize_integer(value), else: value)}
        end)
        |> Map.new()

      {:ok, Projector.find_precedents(query, tenant_id: tenant_id)}
    rescue
      error -> {:error, Errors.from_exception(error)}
    end
  end

  defp normalize_integer(value) when is_integer(value), do: value
  defp normalize_integer(value), do: value |> to_string() |> String.to_integer()
end
