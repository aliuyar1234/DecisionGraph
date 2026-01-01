"""Projection interfaces per SSOT 6.2.

This module defines:
- Projector protocol for projection builders
- Node and Edge dataclasses for context graph
"""

from dataclasses import dataclass, field
from typing import Protocol

from decisiongraph.domain.events import StoredEvent

# =============================================================================
# Node and Edge Types
# =============================================================================

# Node types per SSOT 6.2.2
NODE_TYPE_TRACE = "trace"
NODE_TYPE_ENTITY = "entity"
NODE_TYPE_INPUT = "input"
NODE_TYPE_POLICY = "policy"
NODE_TYPE_EXCEPTION = "exception"
NODE_TYPE_ACTION = "action"
NODE_TYPE_ACTOR = "actor"

ALL_NODE_TYPES = frozenset({
    NODE_TYPE_TRACE,
    NODE_TYPE_ENTITY,
    NODE_TYPE_INPUT,
    NODE_TYPE_POLICY,
    NODE_TYPE_EXCEPTION,
    NODE_TYPE_ACTION,
    NODE_TYPE_ACTOR,
})

# Edge types per SSOT 6.2.4
EDGE_TYPE_TRACE_INVOLVES_ENTITY = "trace_involves_entity"
EDGE_TYPE_TRACE_OBSERVED_INPUT = "trace_observed_input"
EDGE_TYPE_TRACE_EVALUATED_POLICY = "trace_evaluated_policy"
EDGE_TYPE_TRACE_REQUESTED_EXCEPTION = "trace_requested_exception"
EDGE_TYPE_EXCEPTION_APPROVED_BY = "exception_approved_by"
EDGE_TYPE_TRACE_CITED_PRECEDENT = "trace_cited_precedent"
EDGE_TYPE_TRACE_PROPOSED_ACTION = "trace_proposed_action"
EDGE_TYPE_TRACE_COMMITTED_ACTION = "trace_committed_action"
EDGE_TYPE_ACTION_TARGETS_ENTITY = "action_targets_entity"

ALL_EDGE_TYPES = frozenset({
    EDGE_TYPE_TRACE_INVOLVES_ENTITY,
    EDGE_TYPE_TRACE_OBSERVED_INPUT,
    EDGE_TYPE_TRACE_EVALUATED_POLICY,
    EDGE_TYPE_TRACE_REQUESTED_EXCEPTION,
    EDGE_TYPE_EXCEPTION_APPROVED_BY,
    EDGE_TYPE_TRACE_CITED_PRECEDENT,
    EDGE_TYPE_TRACE_PROPOSED_ACTION,
    EDGE_TYPE_TRACE_COMMITTED_ACTION,
    EDGE_TYPE_ACTION_TARGETS_ENTITY,
})


@dataclass(frozen=True)
class Node:
    """Context graph node per SSOT 6.2.2.

    Attributes:
        node_id: Unique node ID in format {node_type}:{node_id}
        node_type: Type of node (trace, entity, policy, etc.)
        trace_id: Trace this node belongs to
        log_seq: log_seq of event that created this node
        created_at: occurred_at of event (NOT wall-clock)
        attrs: Node attributes (MUST be {} in v1 for digest stability)
    """

    node_id: str
    node_type: str
    trace_id: str
    log_seq: int
    created_at: str
    attrs: dict[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        """Validate node_id format."""
        if ":" not in self.node_id:
            raise ValueError(f"node_id must be in format {{type}}:{{id}}, got: {self.node_id}")


@dataclass(frozen=True)
class Edge:
    """Context graph edge per SSOT 6.2.3.

    Attributes:
        edge_id: Unique edge ID in format {edge_type}:{from_key}:{to_key}:{event_id}
        edge_type: Type of edge (trace_involves_entity, etc.)
        from_node_id: Source node ID
        to_node_id: Target node ID
        trace_id: Trace this edge belongs to
        log_seq: log_seq of event that created this edge
        created_at: occurred_at of event (NOT wall-clock)
        attrs: Edge attributes (MUST be {} in v1 for digest stability)
    """

    edge_id: str
    edge_type: str
    from_node_id: str
    to_node_id: str
    trace_id: str
    log_seq: int
    created_at: str
    attrs: dict[str, str] = field(default_factory=dict)


# =============================================================================
# Projector Protocol
# =============================================================================


class Projector(Protocol):
    """Protocol for projection builders per SSOT 6.2.5.

    A projector transforms events from the append-only log into
    queryable read models (projections).

    Implementations must:
    - Process events in log_seq order
    - Produce deterministic output (same events = same projection)
    - Track cursor for resumability
    - NOT use wall-clock time in projections
    """

    def project_event(self, event: StoredEvent) -> None:
        """Project a single event into the projection.

        Args:
            event: Stored event to project

        Raises:
            DecisionGraphError: If event fails validation
        """
        ...

    def rebuild(self) -> None:
        """Rebuild projection from scratch.

        Clears existing projection and replays all events.
        """
        ...

    def get_cursor(self) -> int:
        """Get the last_applied_log_seq cursor.

        Returns:
            Last log_seq that was successfully projected, or 0 if none
        """
        ...


__all__ = [
    # Node types
    "NODE_TYPE_TRACE",
    "NODE_TYPE_ENTITY",
    "NODE_TYPE_INPUT",
    "NODE_TYPE_POLICY",
    "NODE_TYPE_EXCEPTION",
    "NODE_TYPE_ACTION",
    "NODE_TYPE_ACTOR",
    "ALL_NODE_TYPES",
    # Edge types
    "EDGE_TYPE_TRACE_INVOLVES_ENTITY",
    "EDGE_TYPE_TRACE_OBSERVED_INPUT",
    "EDGE_TYPE_TRACE_EVALUATED_POLICY",
    "EDGE_TYPE_TRACE_REQUESTED_EXCEPTION",
    "EDGE_TYPE_EXCEPTION_APPROVED_BY",
    "EDGE_TYPE_TRACE_CITED_PRECEDENT",
    "EDGE_TYPE_TRACE_PROPOSED_ACTION",
    "EDGE_TYPE_TRACE_COMMITTED_ACTION",
    "EDGE_TYPE_ACTION_TARGETS_ENTITY",
    "ALL_EDGE_TYPES",
    # Dataclasses
    "Node",
    "Edge",
    # Protocol
    "Projector",
]
