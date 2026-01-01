"""Storage interface definitions per SSOT 11.6.

This module defines the EventStore protocol that all storage backends must implement.
"""

from typing import Protocol

from decisiongraph.domain.events import EventEnvelope, StoredEvent


class EventStore(Protocol):
    """Protocol for event storage backends.

    All storage backends (SQLite, PostgreSQL, InMemory) must implement
    this protocol per SSOT 11.6.
    """

    def append_event(self, envelope: EventEnvelope) -> StoredEvent:
        """Append event to the store.

        Args:
            envelope: Event envelope to append

        Returns:
            StoredEvent with assigned log_seq, recorded_at, and payload_hash

        Raises:
            DecisionGraphError: With appropriate error code:
                - DG_ERR_IDEMPOTENCY_CONFLICT: Same (producer_id, idempotency_key) with different payload
                - DG_ERR_EVENT_SEQUENCE_INVALID: trace_seq not monotonic
                - DG_ERR_CONFLICT: TraceFinished already exists for trace
                - DG_ERR_PII_POLICY_VIOLATION: Payload contains forbidden content
                - DG_ERR_SCHEMA_VIOLATION: Invalid payload structure
        """
        ...

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
        ...

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
        ...

    def get_last_log_seq(self) -> int:
        """Get the current maximum log_seq.

        Returns:
            Maximum log_seq in the store, or 0 if empty
        """
        ...

    def is_trace_finished(self, trace_id: str) -> bool:
        """Check if a trace has been finished.

        Args:
            trace_id: Trace ID to check

        Returns:
            True if TraceFinished event exists for this trace
        """
        ...

    def get_next_trace_seq(self, trace_id: str) -> int:
        """Get the next expected trace_seq for a trace.

        Args:
            trace_id: Trace ID to check

        Returns:
            Next expected trace_seq (max existing + 1, or 0 if no events)
        """
        ...


__all__ = ["EventStore"]
