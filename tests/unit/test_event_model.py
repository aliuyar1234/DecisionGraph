"""Tests for event model - event types and payloads."""

from dataclasses import FrozenInstanceError

import pytest

from decisiongraph.domain.events import (
    ALL_EVENT_TYPES,
    EVENT_TYPE_ACTION_COMMITTED,
    EVENT_TYPE_ACTION_PROPOSED,
    EVENT_TYPE_APPROVAL_RECORDED,
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_EXCEPTION_REQUESTED,
    EVENT_TYPE_INPUT_OBSERVED,
    EVENT_TYPE_POLICY_EVALUATED,
    EVENT_TYPE_PRECEDENT_CITED,
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
    ActionCommittedPayload,
    ActionProposedPayload,
    ApprovalRecordedPayload,
    EntityObservedPayload,
    EventEnvelope,
    ExceptionRequestedPayload,
    InputObservedPayload,
    PolicyEvaluatedPayload,
    PrecedentCitedPayload,
    StoredEvent,
    TraceFinishedPayload,
    TraceStartedPayload,
)
from decisiongraph.domain.types import (
    ActorRef,
    ApprovalSubject,
    Change,
    EntityRef,
    Fact,
    PolicyRef,
    SourceObjectRef,
    SourceRef,
    Value,
    Violation,
)


class TestEventTypes:
    """Tests for event type constants."""

    def test_all_event_types_count(self) -> None:
        """There are exactly 10 event types."""
        assert len(ALL_EVENT_TYPES) == 10

    def test_event_type_strings(self) -> None:
        """Event types are the expected strings."""
        expected = {
            "TraceStarted",
            "InputObserved",
            "EntityObserved",
            "PolicyEvaluated",
            "ExceptionRequested",
            "ApprovalRecorded",
            "PrecedentCited",
            "ActionProposed",
            "ActionCommitted",
            "TraceFinished",
        }
        assert expected == ALL_EVENT_TYPES

    def test_constants_match_strings(self) -> None:
        """Constants match their string values."""
        assert EVENT_TYPE_TRACE_STARTED == "TraceStarted"
        assert EVENT_TYPE_INPUT_OBSERVED == "InputObserved"
        assert EVENT_TYPE_ENTITY_OBSERVED == "EntityObserved"
        assert EVENT_TYPE_POLICY_EVALUATED == "PolicyEvaluated"
        assert EVENT_TYPE_EXCEPTION_REQUESTED == "ExceptionRequested"
        assert EVENT_TYPE_APPROVAL_RECORDED == "ApprovalRecorded"
        assert EVENT_TYPE_PRECEDENT_CITED == "PrecedentCited"
        assert EVENT_TYPE_ACTION_PROPOSED == "ActionProposed"
        assert EVENT_TYPE_ACTION_COMMITTED == "ActionCommitted"
        assert EVENT_TYPE_TRACE_FINISHED == "TraceFinished"


class TestTraceStartedPayload:
    """Tests for TraceStartedPayload."""

    def test_create(self) -> None:
        """Create TraceStartedPayload."""
        entity = EntityRef(entity_type="Account", entity_id="acc-123")
        payload = TraceStartedPayload(
            workflow="renewal",
            title="Process renewal request",
            primary_entity=entity,
        )

        assert payload.workflow == "renewal"
        assert payload.title == "Process renewal request"
        assert payload.primary_entity == entity
        assert payload.context is None

    def test_with_context(self) -> None:
        """Create with optional context."""
        entity = EntityRef(entity_type="Account", entity_id="acc-123")
        payload = TraceStartedPayload(
            workflow="renewal",
            title="Test",
            primary_entity=entity,
            context={"source": "api", "priority": "high"},
        )

        assert payload.context == {"source": "api", "priority": "high"}


class TestInputObservedPayload:
    """Tests for InputObservedPayload."""

    def test_create(self) -> None:
        """Create InputObservedPayload."""
        source = SourceObjectRef(
            system="email", object_type="Message", object_id="msg-123"
        )
        value = Value(type="string", value="renewal request")
        fact = Fact(key="subject", value=value)

        payload = InputObservedPayload(
            input_id="input-1",
            source=source,
            facts=[fact],
        )

        assert payload.input_id == "input-1"
        assert payload.source == source
        assert len(payload.facts) == 1


class TestEntityObservedPayload:
    """Tests for EntityObservedPayload."""

    def test_create_primary(self) -> None:
        """Create with primary role."""
        entity = EntityRef(entity_type="Account", entity_id="acc-123")
        value = Value(type="decimal", value="1000000")
        fact = Fact(key="arr", value=value)

        payload = EntityObservedPayload(
            entity=entity,
            role="primary",
            facts=[fact],
        )

        assert payload.role == "primary"

    def test_create_related(self) -> None:
        """Create with related role."""
        entity = EntityRef(entity_type="Contact", entity_id="cnt-456")
        payload = EntityObservedPayload(
            entity=entity,
            role="related",
            facts=[],
        )

        assert payload.role == "related"


class TestPolicyEvaluatedPayload:
    """Tests for PolicyEvaluatedPayload."""

    def test_create_allow(self) -> None:
        """Create with allow decision."""
        policy = PolicyRef(policy_id="discount-policy", policy_version="1.0")
        payload = PolicyEvaluatedPayload(
            policy=policy,
            inputs=["input-1", "input-2"],
            decision="allow",
        )

        assert payload.decision == "allow"
        assert payload.violations is None

    def test_create_deny_with_violations(self) -> None:
        """Create with deny decision and violations."""
        policy = PolicyRef(policy_id="discount-policy", policy_version="1.0")
        violation = Violation(
            code="MAX_DISCOUNT", message="Discount exceeds maximum"
        )
        payload = PolicyEvaluatedPayload(
            policy=policy,
            inputs=["input-1"],
            decision="deny",
            violations=[violation],
        )

        assert payload.decision == "deny"
        assert len(payload.violations) == 1

    def test_create_require_exception(self) -> None:
        """Create with require_exception decision."""
        policy = PolicyRef(policy_id="discount-policy", policy_version="1.0")
        payload = PolicyEvaluatedPayload(
            policy=policy,
            inputs=[],
            decision="require_exception",
        )

        assert payload.decision == "require_exception"


class TestExceptionRequestedPayload:
    """Tests for ExceptionRequestedPayload."""

    def test_create(self) -> None:
        """Create ExceptionRequestedPayload."""
        policy = PolicyRef(policy_id="discount-policy", policy_version="1.0")
        payload = ExceptionRequestedPayload(
            exception_id="exc-123",
            policy=policy,
            reason="Customer is strategic partner",
        )

        assert payload.exception_id == "exc-123"
        assert payload.reason == "Customer is strategic partner"
        assert payload.evidence is None


class TestApprovalRecordedPayload:
    """Tests for ApprovalRecordedPayload."""

    def test_create_approved(self) -> None:
        """Create with approved decision."""
        subject = ApprovalSubject(subject_type="exception", subject_id="exc-123")
        approver = ActorRef(actor_type="person", actor_id="manager-1")

        payload = ApprovalRecordedPayload(
            approval_id="apr-1",
            subject=subject,
            approver=approver,
            decision="approved",
        )

        assert payload.decision == "approved"

    def test_create_rejected(self) -> None:
        """Create with rejected decision."""
        subject = ApprovalSubject(subject_type="action", subject_id="act-456")
        approver = ActorRef(actor_type="role", actor_id="finance")

        payload = ApprovalRecordedPayload(
            approval_id="apr-2",
            subject=subject,
            approver=approver,
            decision="rejected",
            reason="Insufficient justification",
        )

        assert payload.decision == "rejected"
        assert payload.reason == "Insufficient justification"


class TestPrecedentCitedPayload:
    """Tests for PrecedentCitedPayload."""

    def test_create(self) -> None:
        """Create PrecedentCitedPayload."""
        payload = PrecedentCitedPayload(
            cited_trace_id="trace-old-123",
            reason="Similar customer with same exception approved",
        )

        assert payload.cited_trace_id == "trace-old-123"
        assert payload.similarity_score is None

    def test_with_similarity_score(self) -> None:
        """Create with similarity score (as string, not float)."""
        payload = PrecedentCitedPayload(
            cited_trace_id="trace-old-123",
            reason="High similarity",
            similarity_score="0.95",  # String, not float!
        )

        assert payload.similarity_score == "0.95"


class TestActionProposedPayload:
    """Tests for ActionProposedPayload."""

    def test_create(self) -> None:
        """Create ActionProposedPayload."""
        entity = EntityRef(entity_type="Account", entity_id="acc-123")
        old_val = Value(type="decimal", value="0")
        new_val = Value(type="decimal", value="20")
        change = Change(path="discount_percent", old_value=old_val, new_value=new_val)

        payload = ActionProposedPayload(
            action_id="act-1",
            action_type="update",
            target_entity=entity,
            target_system="crm",
            changes=[change],
        )

        assert payload.action_id == "act-1"
        assert payload.action_type == "update"
        assert len(payload.changes) == 1


class TestActionCommittedPayload:
    """Tests for ActionCommittedPayload."""

    def test_create_success(self) -> None:
        """Create with success status."""
        payload = ActionCommittedPayload(
            action_id="act-1",
            status="success",
            external_reference="crm-ref-456",
        )

        assert payload.status == "success"
        assert payload.external_reference == "crm-ref-456"
        assert payload.error is None

    def test_create_failure(self) -> None:
        """Create with failure status."""
        payload = ActionCommittedPayload(
            action_id="act-1",
            status="failure",
            error="Connection timeout",
        )

        assert payload.status == "failure"
        assert payload.error == "Connection timeout"

    def test_create_partial(self) -> None:
        """Create with partial status."""
        payload = ActionCommittedPayload(
            action_id="act-1",
            status="partial",
        )

        assert payload.status == "partial"


class TestTraceFinishedPayload:
    """Tests for TraceFinishedPayload."""

    def test_create_success(self) -> None:
        """Create with success outcome."""
        payload = TraceFinishedPayload(outcome="success")

        assert payload.outcome == "success"
        assert payload.summary is None

    def test_create_failure(self) -> None:
        """Create with failure outcome."""
        payload = TraceFinishedPayload(
            outcome="failure",
            summary="Policy violation could not be resolved",
        )

        assert payload.outcome == "failure"
        assert payload.summary is not None

    def test_create_abandoned(self) -> None:
        """Create with abandoned outcome."""
        payload = TraceFinishedPayload(outcome="abandoned")

        assert payload.outcome == "abandoned"


class TestEventEnvelope:
    """Tests for EventEnvelope dataclass."""

    def test_create(self) -> None:
        """Create EventEnvelope."""
        source = SourceRef(producer_id="agent-1", system="renewal")
        actor = ActorRef(actor_type="agent", actor_id="renewal-agent")

        envelope = EventEnvelope(
            event_id="evt-123",
            trace_id="trace-456",
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            occurred_at="2026-01-01T12:00:00.000000Z",
            source=source,
            actor=actor,
            idempotency_key="trace-456-0",
            payload={"workflow": "renewal", "title": "Test"},
        )

        assert envelope.event_id == "evt-123"
        assert envelope.trace_seq == 0
        assert envelope.schema_version == 1  # Default

    def test_frozen(self) -> None:
        """EventEnvelope is immutable."""
        source = SourceRef(producer_id="agent-1", system="test")
        actor = ActorRef(actor_type="agent", actor_id="test")

        envelope = EventEnvelope(
            event_id="evt-1",
            trace_id="trace-1",
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            occurred_at="2026-01-01T00:00:00Z",
            source=source,
            actor=actor,
            idempotency_key="key-1",
            payload={},
        )

        with pytest.raises(FrozenInstanceError):
            envelope.event_id = "changed"  # type: ignore[misc]


class TestStoredEvent:
    """Tests for StoredEvent dataclass."""

    def test_create(self) -> None:
        """Create StoredEvent."""
        source = SourceRef(producer_id="agent-1", system="test")
        actor = ActorRef(actor_type="agent", actor_id="test")

        stored = StoredEvent(
            log_seq=1,
            event_id="evt-123",
            trace_id="trace-456",
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            occurred_at="2026-01-01T12:00:00.000000Z",
            recorded_at="2026-01-01T12:00:01.000000Z",
            source=source,
            actor=actor,
            idempotency_key="trace-456-0",
            payload={"workflow": "test"},
            payload_hash="sha256:abc123",
        )

        assert stored.log_seq == 1
        assert stored.recorded_at == "2026-01-01T12:00:01.000000Z"
        assert stored.payload_hash == "sha256:abc123"

    def test_frozen(self) -> None:
        """StoredEvent is immutable."""
        source = SourceRef(producer_id="agent-1", system="test")
        actor = ActorRef(actor_type="agent", actor_id="test")

        stored = StoredEvent(
            log_seq=1,
            event_id="evt-1",
            trace_id="trace-1",
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            occurred_at="2026-01-01T00:00:00Z",
            recorded_at="2026-01-01T00:00:00Z",
            source=source,
            actor=actor,
            idempotency_key="key-1",
            payload={},
            payload_hash="sha256:test",
        )

        with pytest.raises(FrozenInstanceError):
            stored.log_seq = 999  # type: ignore[misc]
