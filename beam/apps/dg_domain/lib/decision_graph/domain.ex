defmodule DecisionGraph.Domain do
  @moduledoc """
  Shared structs and conventions for the BEAM platform boundary.

  Phase 2 keeps this app intentionally light. It codifies the runtime-facing
  contract shapes we need for bootstrapping without attempting to replace the
  Python semantic oracle.
  """

  @projection_names [:context_graph, :trace_summary, :precedent_index]

  @spec projection_names() :: [atom()]
  def projection_names, do: @projection_names
end
