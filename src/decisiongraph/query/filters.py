"""Query filter types per SSOT 11.8.

This module defines filter and cursor types for querying:
- EventFilter: Filter for event queries
- GraphFilter: Filter for graph queries
- GraphEdgeCursor: Pagination cursor for edge queries
"""

from dataclasses import dataclass
from typing import Literal


@dataclass(frozen=True)
class EventFilter:
    """Filter for event queries per SSOT 7.4.0.

    Attributes:
        trace_id: Filter by trace ID
        event_type: Filter by event type (e.g., "TraceStarted")
        since_log_seq: Only return events with log_seq > this value
        until_log_seq: Only return events with log_seq <= this value
        since_trace_seq: Only return events with trace_seq > this value
        limit: Maximum number of events to return
    """

    trace_id: str | None = None
    event_type: str | None = None
    since_log_seq: int | None = None
    until_log_seq: int | None = None
    since_trace_seq: int | None = None
    limit: int | None = None

    def __post_init__(self) -> None:
        """Validate filter parameters."""
        if self.since_log_seq is not None and self.since_log_seq < 0:
            raise ValueError("since_log_seq must be non-negative")
        if self.until_log_seq is not None and self.until_log_seq < 0:
            raise ValueError("until_log_seq must be non-negative")
        if (
            self.since_log_seq is not None
            and self.until_log_seq is not None
            and self.since_log_seq > self.until_log_seq
        ):
            raise ValueError("since_log_seq must be <= until_log_seq")
        if self.since_trace_seq is not None and self.since_trace_seq < 0:
            raise ValueError("since_trace_seq must be non-negative")
        if self.limit is not None and self.limit <= 0:
            raise ValueError("limit must be positive")
        if self.limit is not None and self.limit > 10000:
            raise ValueError("limit must be <= 10000")


@dataclass(frozen=True)
class GraphFilter:
    """Filter for graph queries per SSOT 7.4.0.

    Attributes:
        edge_types: Filter to specific edge types (e.g., ["trace_involves_entity"])
        node_types: Filter to specific node types (e.g., ["entity", "policy"])
        max_depth: Maximum traversal depth from center node
        max_nodes: Maximum number of nodes to return (truncation limit)
        max_edges: Maximum number of edges to return (truncation limit)
    """

    edge_types: list[str] | None = None
    node_types: list[str] | None = None
    max_depth: int = 1
    max_nodes: int = 100
    max_edges: int = 500

    def __post_init__(self) -> None:
        """Validate filter parameters."""
        if self.max_depth < 0:
            raise ValueError("max_depth must be non-negative")
        if self.max_depth > 10:
            raise ValueError("max_depth must be <= 10")
        if self.max_nodes <= 0:
            raise ValueError("max_nodes must be positive")
        if self.max_edges <= 0:
            raise ValueError("max_edges must be positive")
        if self.edge_types is not None and not self.edge_types:
            raise ValueError("edge_types must not be empty if specified")
        if self.node_types is not None and not self.node_types:
            raise ValueError("node_types must not be empty if specified")


@dataclass(frozen=True)
class GraphEdgeCursor:
    """Pagination cursor for edge queries per SSOT 7.4.0.

    Attributes:
        edge_key: Edge ID to resume from (exclusive - next page starts after this)
        direction: Direction of edges being queried
    """

    edge_key: str
    direction: Literal["outgoing", "incoming", "both"]

    def __post_init__(self) -> None:
        """Validate cursor parameters."""
        if not self.edge_key:
            raise ValueError("edge_key must not be empty")
        if self.direction not in ("outgoing", "incoming", "both"):
            raise ValueError('direction must be "outgoing", "incoming", or "both"')


__all__ = [
    "EventFilter",
    "GraphFilter",
    "GraphEdgeCursor",
]
