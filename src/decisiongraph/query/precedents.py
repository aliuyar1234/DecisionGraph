"""Precedent search functions per SSOT 11.11.

This module provides precedent search functionality:
- PrecedentQuery: Filter for precedent search
- PrecedentHit: Precedent search result
- find_precedents: Find similar past decisions
"""

from dataclasses import dataclass
from typing import TYPE_CHECKING

from decisiongraph.errors import (
    DG_ERR_INVALID_ARGUMENT,
    DG_ERR_PROJECTION_OUT_OF_DATE,
    DecisionGraphError,
)

if TYPE_CHECKING:
    from decisiongraph.projections.projector import SQLiteProjector
    from decisiongraph.storage.interface import EventStore


@dataclass
class PrecedentQuery:
    """Filter for precedent search per SSOT 7.6.0.

    Attributes:
        policy_id: Match traces that evaluated this policy
        policy_version: Match specific policy version (requires policy_id)
        entity_type: Match traces with this primary entity type
        entity_id: Match traces with this primary entity ID (requires entity_type)
        outcome: Match traces with this outcome (e.g., "approved", "denied")
        limit: Maximum number of precedents to return (default 100)
    """

    policy_id: str | None = None
    policy_version: str | None = None
    entity_type: str | None = None
    entity_id: str | None = None
    outcome: str | None = None
    limit: int = 100

    def __post_init__(self) -> None:
        """Validate query parameters."""
        if self.policy_version is not None and self.policy_id is None:
            raise ValueError("policy_version requires policy_id")
        if self.entity_id is not None and self.entity_type is None:
            raise ValueError("entity_id requires entity_type")
        if self.limit <= 0:
            raise ValueError("limit must be positive")
        if self.limit > 10000:
            raise ValueError("limit must be <= 10000")


@dataclass(frozen=True)
class PrecedentHit:
    """Precedent search result per SSOT 7.6.0.

    Attributes:
        trace_id: Trace ID of the precedent
        workflow: Workflow identifier
        title: Human-readable trace title
        outcome: Trace outcome
        policy_id: Policy that was evaluated, or None
        policy_version: Policy version, or None
        finished_at: When the trace finished (from event.occurred_at)
    """

    trace_id: str
    workflow: str
    title: str
    outcome: str
    policy_id: str | None
    policy_version: str | None
    finished_at: str


def _escape_like_wildcards(value: str) -> str:
    """Escape SQL LIKE wildcards in a string.

    Args:
        value: String to escape

    Returns:
        Escaped string safe for LIKE patterns
    """
    # Escape backslash first, then % and _
    return value.replace("\\", "\\\\").replace("%", r"\%").replace("_", r"\_")


def find_precedents(
    store: "EventStore",
    projector: "SQLiteProjector",
    query: PrecedentQuery,
) -> list[PrecedentHit]:
    """Find similar past decisions per SSOT 7.6.1.

    This query searches for finished traces that match the given criteria.
    Results are:
    - Filtered by query parameters
    - Only include finished traces (TraceFinished event exists)
    - Deduplicated by trace_id (max 1 hit per trace)
    - Ordered by last_log_seq descending (most recent first)

    Args:
        store: Event store (for staleness check)
        projector: Projector with precedent index data
        query: Precedent query filter

    Returns:
        List of PrecedentHit ordered by recency (most recent first)

    Raises:
        DecisionGraphError: If projections are stale or invalid arguments
    """
    # Check staleness
    projector_seq = projector.get_cursor()
    event_seq = store.get_last_log_seq()

    if projector_seq < event_seq:
        raise DecisionGraphError(
            DG_ERR_PROJECTION_OUT_OF_DATE,
            f"Projections at log_seq={projector_seq}, events at {event_seq}",
        )

    # Validate limit
    if query.limit > 10000:
        raise DecisionGraphError(
            DG_ERR_INVALID_ARGUMENT,
            f"limit must be <= 10000, got {query.limit}",
        )

    # Access the projector's connection
    conn = projector.connection

    # Build query based on filters
    # We need to find finished traces that match the criteria
    # by joining with policy edges if policy_id is specified

    conditions = ["ts.outcome IS NOT NULL"]  # Only finished traces
    params: list[str | int] = []

    # Filter by outcome
    if query.outcome:
        conditions.append("ts.outcome = ?")
        params.append(query.outcome)

    # Filter by entity type
    if query.entity_type:
        conditions.append("ts.primary_entity_type = ?")
        params.append(query.entity_type)

    # Filter by entity id
    if query.entity_id:
        conditions.append("ts.primary_entity_id = ?")
        params.append(query.entity_id)

    # Build the base query
    if query.policy_id:
        # Join with edges to find traces that evaluated the policy
        if query.policy_version:
            # Exact match with version
            policy_node_id = f"policy:{query.policy_id}:{query.policy_version}"
            policy_condition = "e.to_node_id = ?"
        else:
            # Match any version of this policy - escape wildcards
            escaped_policy = _escape_like_wildcards(query.policy_id)
            policy_node_id = f"policy:{escaped_policy}%"
            policy_condition = "e.to_node_id LIKE ? ESCAPE '\\'"

        sql = f"""
            SELECT DISTINCT
                ts.trace_id,
                ts.workflow,
                ts.title,
                ts.outcome,
                ts.finished_at,
                ts.last_log_seq
            FROM dg_trace_summary ts
            JOIN dg_cg_edges e ON e.trace_id = ts.trace_id
            WHERE {' AND '.join(conditions)}
                AND e.edge_type = 'trace_evaluated_policy'
                AND {policy_condition}
            ORDER BY ts.last_log_seq DESC
            LIMIT ?
        """
        params.append(policy_node_id)
    else:
        # No policy filter - query trace_summary directly
        sql = f"""
            SELECT
                trace_id,
                workflow,
                title,
                outcome,
                finished_at,
                last_log_seq
            FROM dg_trace_summary ts
            WHERE {' AND '.join(conditions)}
            ORDER BY last_log_seq DESC
            LIMIT ?
        """

    params.append(query.limit)

    # Execute query
    cursor = conn.execute(sql, params)
    rows = cursor.fetchall()

    # Convert to PrecedentHit objects
    precedents: list[PrecedentHit] = []
    for row in rows:
        # Extract policy info if we have it
        policy_id = None
        policy_version = None

        if query.policy_id:
            policy_id = query.policy_id
            policy_version = query.policy_version

        precedents.append(
            PrecedentHit(
                trace_id=row["trace_id"],
                workflow=row["workflow"],
                title=row["title"],
                outcome=row["outcome"],
                policy_id=policy_id,
                policy_version=policy_version,
                finished_at=row["finished_at"],
            )
        )

    return precedents


__all__ = [
    "PrecedentQuery",
    "PrecedentHit",
    "find_precedents",
]
