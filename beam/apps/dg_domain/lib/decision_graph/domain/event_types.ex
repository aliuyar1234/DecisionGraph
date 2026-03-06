defmodule DecisionGraph.Domain.EventTypes do
  @moduledoc """
  Frozen event vocabulary mirrored from the Python semantic reference.
  """

  @trace_started "TraceStarted"
  @input_observed "InputObserved"
  @entity_observed "EntityObserved"
  @policy_evaluated "PolicyEvaluated"
  @exception_requested "ExceptionRequested"
  @approval_recorded "ApprovalRecorded"
  @precedent_cited "PrecedentCited"
  @action_proposed "ActionProposed"
  @action_committed "ActionCommitted"
  @trace_finished "TraceFinished"

  @all [
    @trace_started,
    @input_observed,
    @entity_observed,
    @policy_evaluated,
    @exception_requested,
    @approval_recorded,
    @precedent_cited,
    @action_proposed,
    @action_committed,
    @trace_finished
  ]

  @spec all() :: [String.t()]
  def all, do: @all

  @spec trace_started() :: String.t()
  def trace_started, do: @trace_started

  @spec input_observed() :: String.t()
  def input_observed, do: @input_observed

  @spec entity_observed() :: String.t()
  def entity_observed, do: @entity_observed

  @spec policy_evaluated() :: String.t()
  def policy_evaluated, do: @policy_evaluated

  @spec exception_requested() :: String.t()
  def exception_requested, do: @exception_requested

  @spec approval_recorded() :: String.t()
  def approval_recorded, do: @approval_recorded

  @spec precedent_cited() :: String.t()
  def precedent_cited, do: @precedent_cited

  @spec action_proposed() :: String.t()
  def action_proposed, do: @action_proposed

  @spec action_committed() :: String.t()
  def action_committed, do: @action_committed

  @spec trace_finished() :: String.t()
  def trace_finished, do: @trace_finished
end
