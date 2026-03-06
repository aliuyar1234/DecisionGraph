defmodule DecisionGraph.Observability.LogContext do
  @moduledoc "Structured logging metadata conventions shared across apps."

  require Logger

  alias DecisionGraph.Domain.RuntimeContext

  @spec put(RuntimeContext.t() | map()) :: :ok
  def put(%RuntimeContext{} = context) do
    context
    |> RuntimeContext.logger_metadata()
    |> Logger.metadata()

    :ok
  end

  def put(metadata) when is_map(metadata) do
    metadata
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Logger.metadata()

    :ok
  end

  @spec clear() :: :ok
  def clear do
    Logger.reset_metadata(DecisionGraph.Observability.metadata_keys())
    :ok
  end
end
