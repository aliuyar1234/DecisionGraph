"""Projection health inspection helpers."""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING

from decisiongraph.projections.digests import (
    compute_context_graph_digest,
    compute_full_projection_digest,
    compute_precedent_index_digest,
    compute_trace_summary_digest,
)
from decisiongraph.projections.interfaces import ProjectionBackend

if TYPE_CHECKING:
    from decisiongraph.storage.interface import EventStore


@dataclass(frozen=True)
class ProjectionHealth:
    """Current projection state relative to the event log."""

    event_count: int
    trace_count: int
    event_log_last_seq: int
    projected_last_seq: int
    pending_events: int
    is_stale: bool
    digests: dict[str, str] | None = None


def get_projection_health(
    store: EventStore,
    projector: ProjectionBackend,
    *,
    include_digests: bool = False,
) -> ProjectionHealth:
    """Return projection cursor lag and optional digest information."""
    event_log_last_seq = store.get_last_log_seq()
    projected_last_seq = projector.get_cursor()
    pending_events = max(event_log_last_seq - projected_last_seq, 0)
    counts_row = projector.execute_query(
        """
        SELECT
            COUNT(*) AS event_count,
            COUNT(DISTINCT trace_id) AS trace_count
        FROM dg_event_log
        """
    )
    event_count = int(counts_row[0]["event_count"]) if counts_row else 0
    trace_count = int(counts_row[0]["trace_count"]) if counts_row else 0

    digests: dict[str, str] | None = None
    if include_digests:
        conn = projector.connection
        digests = {
            "context_graph": compute_context_graph_digest(conn),
            "trace_summary": compute_trace_summary_digest(conn),
            "precedent_index": compute_precedent_index_digest(conn),
            "full_projection": compute_full_projection_digest(conn),
        }

    return ProjectionHealth(
        event_count=event_count,
        trace_count=trace_count,
        event_log_last_seq=event_log_last_seq,
        projected_last_seq=projected_last_seq,
        pending_events=pending_events,
        is_stale=projected_last_seq < event_log_last_seq,
        digests=digests,
    )


__all__ = ["ProjectionHealth", "get_projection_health"]
