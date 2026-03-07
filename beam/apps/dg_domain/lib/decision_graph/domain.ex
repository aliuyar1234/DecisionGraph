defmodule DecisionGraph.Domain do
  @moduledoc """
  Shared semantic contracts and conventions for the BEAM platform boundary.
  """

  @event_types [
    "TraceStarted",
    "InputObserved",
    "EntityObserved",
    "PolicyEvaluated",
    "ExceptionRequested",
    "ApprovalRecorded",
    "WorkflowReviewRequested",
    "PrecedentCited",
    "ActionProposed",
    "ActionCommitted",
    "TraceFinished"
  ]
  @projection_names [:context_graph, :trace_summary, :precedent_index]

  @spec event_types() :: [String.t()]
  def event_types, do: @event_types

  @spec projection_names() :: [atom()]
  def projection_names, do: @projection_names
end
