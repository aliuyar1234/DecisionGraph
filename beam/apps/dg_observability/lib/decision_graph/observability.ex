defmodule DecisionGraph.Observability do
  @moduledoc """
  Shared telemetry and logging helpers for the BEAM platform.
  """

  @metadata_keys [:request_id, :trace_id, :tenant_id, :projection, :worker]

  @spec emit([atom()], map(), map()) :: :ok
  def emit(suffix, measurements, metadata \\ %{}) do
    :telemetry.execute([:decision_graph | suffix], measurements, metadata)
  end

  @spec metadata_keys() :: [atom()]
  def metadata_keys, do: @metadata_keys
end
