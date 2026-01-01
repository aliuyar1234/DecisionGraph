"""Fake implementations for testing.

This module provides InMemoryEventStore for unit tests without database.
"""

from dataclasses import dataclass, field
from typing import Any

from decisiongraph.domain.events import (
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
    EventEnvelope,
    StoredEvent,
)
from decisiongraph.domain.validation import (
    check_pii_guard,
    validate_idempotency_key,
)
from decisiongraph.errors import (
    DG_ERR_CONFLICT,
    DG_ERR_EVENT_SEQUENCE_INVALID,
    DG_ERR_IDEMPOTENCY_CONFLICT,
    DecisionGraphError,
)
from decisiongraph.serialization import compute_payload_hash
from decisiongraph.time import now_rfc3339


@dataclass
class InMemoryEventStore:
    """In-memory event store for testing.

    Implements the EventStore protocol without persistence.
    All data is stored in memory and lost when the instance is garbage collected.

    This implementation enforces:
    - Idempotency via (producer_id, idempotency_key) uniqueness
    - trace_seq monotonicity within traces
    - TraceFinished locks traces (no more events after finish)
    - PII guard on payloads
    """

    # Internal storage
    _events: list[StoredEvent] = field(default_factory=list)
    _events_by_trace: dict[str, list[StoredEvent]] = field(default_factory=dict)
    _idempotency_index: dict[tuple[str, str], StoredEvent] = field(
        default_factory=dict
    )
    _finished_traces: set[str] = field(default_factory=set)
    _next_log_seq: int = 1

    def append_event(self, envelope: EventEnvelope) -> StoredEvent:
        """Append event to the store.

        Args:
            envelope: Event envelope to append

        Returns:
            StoredEvent with assigned log_seq, recorded_at, and payload_hash

        Raises:
            DecisionGraphError: With appropriate error code
        """
        # Validate idempotency key
        validate_idempotency_key(envelope.idempotency_key)

        # Check PII guard
        check_pii_guard(envelope.payload)

        # Check idempotency - use producer_id from source
        idem_key = (envelope.source.producer_id, envelope.idempotency_key)
        if idem_key in self._idempotency_index:
            existing = self._idempotency_index[idem_key]
            # Same idempotency key - return existing if payload matches
            existing_hash = existing.payload_hash
            new_hash = compute_payload_hash(envelope.payload)
            if existing_hash == new_hash:
                # Idempotent retry - return existing event
                return existing
            else:
                # Different payload - conflict
                raise DecisionGraphError(
                    DG_ERR_IDEMPOTENCY_CONFLICT,
                    f"Idempotency key '{envelope.idempotency_key}' already used "
                    f"with different payload",
                )

        # Check if trace is finished
        if envelope.trace_id in self._finished_traces:
            raise DecisionGraphError(
                DG_ERR_CONFLICT,
                f"Trace '{envelope.trace_id}' is already finished",
            )

        # Validate trace_seq
        expected_seq = self.get_next_trace_seq(envelope.trace_id)
        if envelope.trace_seq != expected_seq:
            raise DecisionGraphError(
                DG_ERR_EVENT_SEQUENCE_INVALID,
                f"Expected trace_seq {expected_seq}, got {envelope.trace_seq}",
            )

        # TraceStarted must be first event (trace_seq=0)
        if envelope.event_type == EVENT_TYPE_TRACE_STARTED and envelope.trace_seq != 0:
            raise DecisionGraphError(
                DG_ERR_EVENT_SEQUENCE_INVALID,
                "TraceStarted must have trace_seq=0",
            )

        # Non-TraceStarted must not be first event
        if envelope.event_type != EVENT_TYPE_TRACE_STARTED and envelope.trace_seq == 0:
            raise DecisionGraphError(
                DG_ERR_EVENT_SEQUENCE_INVALID,
                f"First event must be TraceStarted, got {envelope.event_type}",
            )

        # Compute payload hash
        payload_hash = compute_payload_hash(envelope.payload)

        # Create stored event
        stored = StoredEvent(
            log_seq=self._next_log_seq,
            event_id=envelope.event_id,
            trace_id=envelope.trace_id,
            trace_seq=envelope.trace_seq,
            event_type=envelope.event_type,
            occurred_at=envelope.occurred_at,
            recorded_at=now_rfc3339(),
            source=envelope.source,
            actor=envelope.actor,
            idempotency_key=envelope.idempotency_key,
            payload=envelope.payload,
            payload_hash=payload_hash,
            correlation_id=envelope.correlation_id,
            causation_event_id=envelope.causation_event_id,
            schema_version=envelope.schema_version,
            tags=list(envelope.tags),
        )

        # Store event
        self._events.append(stored)
        if envelope.trace_id not in self._events_by_trace:
            self._events_by_trace[envelope.trace_id] = []
        self._events_by_trace[envelope.trace_id].append(stored)
        self._idempotency_index[idem_key] = stored
        self._next_log_seq += 1

        # Mark trace as finished if TraceFinished
        if envelope.event_type == EVENT_TYPE_TRACE_FINISHED:
            self._finished_traces.add(envelope.trace_id)

        return stored

    def get_trace_events(
        self,
        trace_id: str,
        since_trace_seq: int | None = None,
        limit: int | None = None,
    ) -> list[StoredEvent]:
        """Get events for a trace, ordered by trace_seq.

        Args:
            trace_id: Trace ID to get events for
            since_trace_seq: Only return events with trace_seq > this value
            limit: Maximum number of events to return

        Returns:
            List of stored events ordered by trace_seq
        """
        events = self._events_by_trace.get(trace_id, [])

        # Filter by since_trace_seq
        if since_trace_seq is not None:
            events = [e for e in events if e.trace_seq > since_trace_seq]

        # Already ordered by trace_seq (insertion order)
        # Apply limit
        if limit is not None:
            events = events[:limit]

        return events

    def list_events(
        self,
        since_log_seq: int | None = None,
        until_log_seq: int | None = None,
        event_type: str | None = None,
        trace_id: str | None = None,
        limit: int | None = None,
    ) -> list[StoredEvent]:
        """List events from the global log, ordered by log_seq.

        Args:
            since_log_seq: Only return events with log_seq > this value
            until_log_seq: Only return events with log_seq <= this value
            event_type: Filter by event type
            trace_id: Filter by trace ID
            limit: Maximum number of events to return

        Returns:
            List of stored events ordered by log_seq
        """
        events = self._events

        # Apply filters
        if since_log_seq is not None:
            events = [e for e in events if e.log_seq > since_log_seq]
        if until_log_seq is not None:
            events = [e for e in events if e.log_seq <= until_log_seq]
        if event_type is not None:
            events = [e for e in events if e.event_type == event_type]
        if trace_id is not None:
            events = [e for e in events if e.trace_id == trace_id]

        # Apply limit
        if limit is not None:
            events = events[:limit]

        return events

    def get_last_log_seq(self) -> int:
        """Get the current maximum log_seq.

        Returns:
            Maximum log_seq in the store, or 0 if empty
        """
        if not self._events:
            return 0
        return self._events[-1].log_seq

    def is_trace_finished(self, trace_id: str) -> bool:
        """Check if a trace has been finished.

        Args:
            trace_id: Trace ID to check

        Returns:
            True if TraceFinished event exists for this trace
        """
        return trace_id in self._finished_traces

    def get_next_trace_seq(self, trace_id: str) -> int:
        """Get the next expected trace_seq for a trace.

        Args:
            trace_id: Trace ID to check

        Returns:
            Next expected trace_seq (max existing + 1, or 0 if no events)
        """
        events = self._events_by_trace.get(trace_id, [])
        if not events:
            return 0
        return events[-1].trace_seq + 1

    def clear(self) -> None:
        """Clear all stored events.

        Useful for test isolation.
        """
        self._events.clear()
        self._events_by_trace.clear()
        self._idempotency_index.clear()
        self._finished_traces.clear()
        self._next_log_seq = 1


def create_test_envelope(
    trace_id: str,
    trace_seq: int,
    event_type: str,
    payload: dict[str, Any],
    *,
    event_id: str | None = None,
    producer_id: str = "test-producer",
    idempotency_key: str | None = None,
    actor_type: str = "agent",
    actor_id: str = "test-agent",
) -> EventEnvelope:
    """Create an EventEnvelope for testing.

    Convenience function to create test events with minimal boilerplate.

    Args:
        trace_id: Trace ID
        trace_seq: Sequence number within trace
        event_type: Event type string
        payload: Event payload dict
        event_id: Optional event ID (generated if not provided)
        producer_id: Producer ID for source
        idempotency_key: Idempotency key (generated if not provided)
        actor_type: Actor type
        actor_id: Actor ID

    Returns:
        EventEnvelope ready for append_event()
    """
    from decisiongraph.domain.types import ActorRef, SourceRef
    from decisiongraph.ids import generate_event_id
    from decisiongraph.time import now_rfc3339

    return EventEnvelope(
        event_id=event_id or generate_event_id(),
        trace_id=trace_id,
        trace_seq=trace_seq,
        event_type=event_type,
        occurred_at=now_rfc3339(),
        source=SourceRef(producer_id=producer_id, system="test"),
        actor=ActorRef(actor_type=actor_type, actor_id=actor_id),  # type: ignore[arg-type]
        idempotency_key=idempotency_key or f"{trace_id}-{trace_seq}",
        payload=payload,
    )


__all__ = [
    "InMemoryEventStore",
    "create_test_envelope",
]
