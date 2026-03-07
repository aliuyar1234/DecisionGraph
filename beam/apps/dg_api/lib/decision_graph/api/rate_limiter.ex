defmodule DecisionGraph.Api.RateLimiter do
  @moduledoc false

  alias DecisionGraph.Api.Errors
  alias DecisionGraph.Api.HttpError

  @table :decision_graph_api_rate_limiter
  @defaults %{admin: 60, read: 600, write: 300}

  @spec check(atom(), String.t()) :: :ok | {:error, HttpError.t()}
  def check(bucket, key) when is_atom(bucket) do
    ensure_table!()
    limit = configured_limit(bucket)
    window = System.system_time(:second) |> div(60)
    table_key = {bucket, key, window}
    count = :ets.update_counter(@table, table_key, {2, 1}, {table_key, 0})

    if count > limit do
      {:error, Errors.rate_limited("Rate limit exceeded for #{Atom.to_string(bucket)} API scope")}
    else
      :ok
    end
  end

  defp configured_limit(bucket) do
    Application.get_env(:dg_api, :rate_limits, %{})
    |> Map.new()
    |> Map.get(bucket, Map.fetch!(@defaults, bucket))
  end

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])

        :ok

      _ ->
        :ok
    end
  rescue
    ArgumentError -> :ok
  end
end
