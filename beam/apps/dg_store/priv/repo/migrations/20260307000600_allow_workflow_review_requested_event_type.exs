defmodule DecisionGraph.Store.Repo.Migrations.AllowWorkflowReviewRequestedEventType do
  use Ecto.Migration

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

  def up do
    execute("ALTER TABLE dg_event_log DROP CONSTRAINT IF EXISTS dg_event_log_event_type_valid")

    execute("""
    ALTER TABLE dg_event_log
    ADD CONSTRAINT dg_event_log_event_type_valid
    CHECK (event_type IN (#{Enum.map_join(@event_types, ", ", &"'#{&1}'")}))
    """)
  end

  def down do
    execute("ALTER TABLE dg_event_log DROP CONSTRAINT IF EXISTS dg_event_log_event_type_valid")

    execute("""
    ALTER TABLE dg_event_log
    ADD CONSTRAINT dg_event_log_event_type_valid
    CHECK (event_type IN (
      'TraceStarted',
      'InputObserved',
      'EntityObserved',
      'PolicyEvaluated',
      'ExceptionRequested',
      'ApprovalRecorded',
      'PrecedentCited',
      'ActionProposed',
      'ActionCommitted',
      'TraceFinished'
    ))
    """)
  end
end
