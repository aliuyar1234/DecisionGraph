"""Event envelope and stored event types per SSOT 11.3.

This module defines:
- EventEnvelope: Pre-storage event structure
- StoredEvent: Post-storage event with log_seq and recorded_at
- 10 event type payload dataclasses
"""

from dataclasses import dataclass, field
from typing import Any, Literal

from decisiongraph.domain.types import (
    ActorRef,
    ApprovalSubject,
    Change,
    EntityRef,
    EvidenceRef,
    Fact,
    PolicyRef,
    SourceObjectRef,
    SourceRef,
    Violation,
)

# Event type constants
EVENT_TYPE_TRACE_STARTED = "TraceStarted"
EVENT_TYPE_INPUT_OBSERVED = "InputObserved"
EVENT_TYPE_ENTITY_OBSERVED = "EntityObserved"
EVENT_TYPE_POLICY_EVALUATED = "PolicyEvaluated"
EVENT_TYPE_EXCEPTION_REQUESTED = "ExceptionRequested"
EVENT_TYPE_APPROVAL_RECORDED = "ApprovalRecorded"
EVENT_TYPE_PRECEDENT_CITED = "PrecedentCited"
EVENT_TYPE_ACTION_PROPOSED = "ActionProposed"
EVENT_TYPE_ACTION_COMMITTED = "ActionCommitted"
EVENT_TYPE_TRACE_FINISHED = "TraceFinished"

ALL_EVENT_TYPES = frozenset({
    EVENT_TYPE_TRACE_STARTED,
    EVENT_TYPE_INPUT_OBSERVED,
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_POLICY_EVALUATED,
    EVENT_TYPE_EXCEPTION_REQUESTED,
    EVENT_TYPE_APPROVAL_RECORDED,
    EVENT_TYPE_PRECEDENT_CITED,
    EVENT_TYPE_ACTION_PROPOSED,
    EVENT_TYPE_ACTION_COMMITTED,
    EVENT_TYPE_TRACE_FINISHED,
})


# =============================================================================
# Event Payloads (10 types per SSOT 6.1.3)
# =============================================================================


@dataclass(frozen=True)
class TraceStartedPayload:
    """Payload for TraceStarted event (trace_seq must be 0).

    Attributes:
        workflow: Workflow identifier (e.g., "renewal", "support")
        title: Human-readable trace title
        primary_entity: The main entity this trace is about
        context: Optional additional context key-value pairs
    """

    workflow: str
    title: str
    primary_entity: EntityRef
    context: dict[str, str] | None = None


@dataclass(frozen=True)
class InputObservedPayload:
    """Payload for InputObserved event.

    Attributes:
        input_id: Unique identifier for this input observation
        source: Reference to the source system/object
        facts: List of facts extracted from the input
    """

    input_id: str
    source: SourceObjectRef
    facts: list[Fact]


@dataclass(frozen=True)
class EntityObservedPayload:
    """Payload for EntityObserved event.

    Attributes:
        entity: The entity being observed
        role: Whether this is the primary entity or a related one
        facts: List of facts about the entity
    """

    entity: EntityRef
    role: Literal["primary", "related"]
    facts: list[Fact]


@dataclass(frozen=True)
class PolicyEvaluatedPayload:
    """Payload for PolicyEvaluated event.

    Attributes:
        policy: Reference to the policy being evaluated
        inputs: List of input_ids used for evaluation
        decision: The policy decision
        violations: Optional list of violations if decision is deny/require_exception
        explanation: Optional explanation dict
    """

    policy: PolicyRef
    inputs: list[str]
    decision: Literal["allow", "deny", "require_exception"]
    violations: list[Violation] | None = None
    explanation: dict[str, Any] | None = None


@dataclass(frozen=True)
class ExceptionRequestedPayload:
    """Payload for ExceptionRequested event.

    Attributes:
        exception_id: Unique identifier for this exception request
        policy: Reference to the policy requiring exception
        reason: Reason for requesting the exception
        evidence: Optional supporting evidence
    """

    exception_id: str
    policy: PolicyRef
    reason: str
    evidence: list[EvidenceRef] | None = None


@dataclass(frozen=True)
class ApprovalRecordedPayload:
    """Payload for ApprovalRecorded event.

    Attributes:
        approval_id: Unique identifier for this approval
        subject: What is being approved (exception or action)
        approver: Who approved/rejected
        decision: The approval decision
        reason: Optional reason for decision
        evidence: Optional supporting evidence
    """

    approval_id: str
    subject: ApprovalSubject
    approver: ActorRef
    decision: Literal["approved", "rejected"]
    reason: str | None = None
    evidence: list[EvidenceRef] | None = None


@dataclass(frozen=True)
class PrecedentCitedPayload:
    """Payload for PrecedentCited event.

    Attributes:
        cited_trace_id: Trace ID of the precedent being cited
        reason: Why this precedent is relevant
        similarity_score: Optional similarity score as string (no floats)
    """

    cited_trace_id: str
    reason: str
    similarity_score: str | None = None


@dataclass(frozen=True)
class ActionProposedPayload:
    """Payload for ActionProposed event.

    Attributes:
        action_id: Unique identifier for this proposed action
        action_type: Type of action (e.g., "update", "create")
        target_entity: Entity the action will affect
        target_system: System where action will be executed
        changes: List of proposed changes
    """

    action_id: str
    action_type: str
    target_entity: EntityRef
    target_system: str
    changes: list[Change]


@dataclass(frozen=True)
class ActionCommittedPayload:
    """Payload for ActionCommitted event.

    Attributes:
        action_id: ID of the proposed action being committed
        status: Outcome of the commit
        external_reference: Optional reference to external system record
        error: Optional error message if status is failure/partial
    """

    action_id: str
    status: Literal["success", "failure", "partial"]
    external_reference: str | None = None
    error: str | None = None


@dataclass(frozen=True)
class TraceFinishedPayload:
    """Payload for TraceFinished event (locks the trace).

    Attributes:
        outcome: Final outcome of the trace
        summary: Optional summary of what happened
    """

    outcome: Literal["success", "failure", "abandoned"]
    summary: str | None = None


# =============================================================================
# Event Envelope and Stored Event
# =============================================================================


@dataclass(frozen=True)
class EventEnvelope:
    """Pre-storage event envelope per SSOT 11.3.

    Contains all event data except log_seq (assigned by storage).

    Attributes:
        event_id: Unique identifier for the event (UUID4)
        trace_id: Trace this event belongs to (UUID4)
        trace_seq: Sequence number within trace (starts at 0)
        event_type: Type of event (e.g., "TraceStarted")
        occurred_at: RFC3339 timestamp when event occurred
        source: Producer identification
        actor: Actor who caused the event
        correlation_id: Optional correlation ID for cross-trace linking
        causation_event_id: Optional ID of event that caused this one
        idempotency_key: Key for idempotent submission
        schema_version: Schema version (default 1)
        payload: Event-specific payload data
        tags: Optional tags for filtering
    """

    event_id: str
    trace_id: str
    trace_seq: int
    event_type: str
    occurred_at: str
    source: SourceRef
    actor: ActorRef
    idempotency_key: str
    payload: dict[str, Any]
    correlation_id: str | None = None
    causation_event_id: str | None = None
    schema_version: int = 1
    tags: list[str] = field(default_factory=list)


@dataclass(frozen=True)
class StoredEvent:
    """Persisted event with storage metadata per SSOT 11.3.

    Extends EventEnvelope with:
    - log_seq: Global sequence number assigned by storage
    - recorded_at: RFC3339 timestamp when event was persisted
    - payload_hash: SHA-256 hash of canonical payload JSON

    Attributes:
        log_seq: Global sequence number (assigned by storage)
        event_id: Unique identifier for the event (UUID4)
        trace_id: Trace this event belongs to (UUID4)
        trace_seq: Sequence number within trace (starts at 0)
        event_type: Type of event (e.g., "TraceStarted")
        occurred_at: RFC3339 timestamp when event occurred
        recorded_at: RFC3339 timestamp when event was stored
        source: Producer identification
        actor: Actor who caused the event
        correlation_id: Optional correlation ID for cross-trace linking
        causation_event_id: Optional ID of event that caused this one
        idempotency_key: Key for idempotent submission
        schema_version: Schema version (default 1)
        payload: Event-specific payload data
        payload_hash: SHA-256 hash of canonical payload JSON
        tags: Optional tags for filtering
    """

    log_seq: int
    event_id: str
    trace_id: str
    trace_seq: int
    event_type: str
    occurred_at: str
    recorded_at: str
    source: SourceRef
    actor: ActorRef
    idempotency_key: str
    payload: dict[str, Any]
    payload_hash: str
    correlation_id: str | None = None
    causation_event_id: str | None = None
    schema_version: int = 1
    tags: list[str] = field(default_factory=list)


__all__ = [
    # Event types
    "EVENT_TYPE_TRACE_STARTED",
    "EVENT_TYPE_INPUT_OBSERVED",
    "EVENT_TYPE_ENTITY_OBSERVED",
    "EVENT_TYPE_POLICY_EVALUATED",
    "EVENT_TYPE_EXCEPTION_REQUESTED",
    "EVENT_TYPE_APPROVAL_RECORDED",
    "EVENT_TYPE_PRECEDENT_CITED",
    "EVENT_TYPE_ACTION_PROPOSED",
    "EVENT_TYPE_ACTION_COMMITTED",
    "EVENT_TYPE_TRACE_FINISHED",
    "ALL_EVENT_TYPES",
    # Payloads
    "TraceStartedPayload",
    "InputObservedPayload",
    "EntityObservedPayload",
    "PolicyEvaluatedPayload",
    "ExceptionRequestedPayload",
    "ApprovalRecordedPayload",
    "PrecedentCitedPayload",
    "ActionProposedPayload",
    "ActionCommittedPayload",
    "TraceFinishedPayload",
    # Envelope/Stored
    "EventEnvelope",
    "StoredEvent",
]
