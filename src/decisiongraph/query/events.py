"""Event query functions per SSOT 11.9.

This module provides event query functionality:
- TraceSummary: Trace metadata
- get_trace_summary: Get trace metadata
- get_trace_events: Get events for a trace
- list_events: List events from global log
"""

from dataclasses import dataclass
from typing import TYPE_CHECKING

from decisiongraph.errors import (
    DG_ERR_INVALID_ARGUMENT,
    DG_ERR_NOT_FOUND,
    DecisionGraphError,
)

if TYPE_CHECKING:
    from decisiongraph.domain.events import StoredEvent
    from decisiongraph.projections.projector import SQLiteProjector
    from decisiongraph.storage.interface import EventStore


@dataclass(frozen=True)
class TraceSummary:
    """Trace metadata per SSOT 7.4.0.

    Attributes:
        trace_id: Unique trace identifier
        workflow: Workflow identifier (e.g., "renewal", "support")
        title: Human-readable trace title
        primary_entity_type: Type of the primary entity
        primary_entity_id: ID of the primary entity
        started_at: When the trace started (from event.occurred_at)
        finished_at: When the trace finished, or None if unfinished
        outcome: Trace outcome (e.g., "approved", "denied"), or None if unfinished
    """

    trace_id: str
    workflow: str
    title: str
    primary_entity_type: str
    primary_entity_id: str
    started_at: str
    finished_at: str | None
    outcome: str | None


def get_trace_summary(
    _store: "EventStore",
    projector: "SQLiteProjector",
    trace_id: str,
) -> TraceSummary:
    """Get trace metadata per SSOT 7.4.1.

    This query returns metadata for a trace from the trace summary projection.

    Args:
        _store: Event store (for staleness check, not used for event-log queries)
        projector: Projector with trace summary data
        trace_id: Trace ID to get summary for

    Returns:
        TraceSummary with trace metadata

    Raises:
        DecisionGraphError: If trace not found (DG_ERR_NOT_FOUND)
    """
    # Use the projector's get_trace_summary method
    row = projector.get_trace_summary(trace_id)

    if row is None:
        raise DecisionGraphError(
            DG_ERR_NOT_FOUND,
            f"Trace not found: {trace_id}",
        )

    # Convert row dict to TraceSummary
    return TraceSummary(
        trace_id=row["trace_id"],
        workflow=row["workflow"],
        title=row["title"],
        primary_entity_type=row["primary_entity_type"] or "",
        primary_entity_id=row["primary_entity_id"] or "",
        started_at=row["started_at"],
        finished_at=row["finished_at"],
        outcome=row["outcome"],
    )


def get_trace_events(
    store: "EventStore",
    trace_id: str,
    since_trace_seq: int | None = None,
    limit: int | None = None,
) -> list["StoredEvent"]:
    """Get events for a trace per SSOT 7.4.2.

    This query returns events for a trace, ordered by trace_seq.
    This is an event-log-only query and does NOT check projection staleness.

    Args:
        store: Event store to query
        trace_id: Trace ID to get events for
        since_trace_seq: Only return events with trace_seq > this value
        limit: Maximum number of events to return

    Returns:
        List of stored events ordered by trace_seq

    Raises:
        DecisionGraphError: If trace not found or invalid arguments
    """
    # Validate limit
    if limit is not None and limit > 10000:
        raise DecisionGraphError(
            DG_ERR_INVALID_ARGUMENT,
            f"limit must be <= 10000, got {limit}",
        )

    # Query from event store (delegates to storage backend)
    events = store.get_trace_events(
        trace_id=trace_id,
        since_trace_seq=since_trace_seq,
        limit=limit,
    )

    # If no events found, raise NOT_FOUND
    if not events:
        raise DecisionGraphError(
            DG_ERR_NOT_FOUND,
            f"Trace not found: {trace_id}",
        )

    return events


def list_events(
    store: "EventStore",
    since_log_seq: int | None = None,
    until_log_seq: int | None = None,
    event_type: str | None = None,
    limit: int | None = None,
) -> list["StoredEvent"]:
    """List events from global log per SSOT 7.4.3.

    This query returns events from the global log, ordered by log_seq.
    This is an event-log-only query and does NOT check projection staleness.

    Args:
        store: Event store to query
        since_log_seq: Only return events with log_seq > this value
        until_log_seq: Only return events with log_seq <= this value
        event_type: Filter by event type
        limit: Maximum number of events to return

    Returns:
        List of stored events ordered by log_seq

    Raises:
        DecisionGraphError: If invalid arguments
    """
    # Validate arguments
    if (
        since_log_seq is not None
        and until_log_seq is not None
        and since_log_seq > until_log_seq
    ):
        raise DecisionGraphError(
            DG_ERR_INVALID_ARGUMENT,
            f"since_log_seq ({since_log_seq}) must be <= until_log_seq ({until_log_seq})",
        )

    if limit is not None and limit > 10000:
        raise DecisionGraphError(
            DG_ERR_INVALID_ARGUMENT,
            f"limit must be <= 10000, got {limit}",
        )

    # Query from event store (delegates to storage backend)
    events = store.list_events(
        since_log_seq=since_log_seq,
        until_log_seq=until_log_seq,
        event_type=event_type,
        limit=limit,
    )

    return events


__all__ = [
    "TraceSummary",
    "get_trace_summary",
    "get_trace_events",
    "list_events",
]
