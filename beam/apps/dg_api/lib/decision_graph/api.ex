defmodule DecisionGraph.Api do
  @moduledoc """
  Service-facing bootstrap snapshot for the BEAM platform.
  """

  alias DecisionGraph.Api.Health

  @spec bootstrap_snapshot() :: map()
  def bootstrap_snapshot, do: Health.snapshot()
end
