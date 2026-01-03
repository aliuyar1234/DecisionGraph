"""Context graph emission logic per SSOT 6.2.

This module transforms events into nodes and edges for the context graph.
Each event type produces specific nodes and edges according to SSOT 6.2.4.
"""

from dataclasses import dataclass

from decisiongraph.domain.events import (
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
    StoredEvent,
)
from decisiongraph.projections.interfaces import (
    EDGE_TYPE_ACTION_TARGETS_ENTITY,
    EDGE_TYPE_EXCEPTION_APPROVED_BY,
    EDGE_TYPE_TRACE_CITED_PRECEDENT,
    EDGE_TYPE_TRACE_COMMITTED_ACTION,
    EDGE_TYPE_TRACE_EVALUATED_POLICY,
    EDGE_TYPE_TRACE_INVOLVES_ENTITY,
    EDGE_TYPE_TRACE_OBSERVED_INPUT,
    EDGE_TYPE_TRACE_PROPOSED_ACTION,
    EDGE_TYPE_TRACE_REQUESTED_EXCEPTION,
    NODE_TYPE_ACTION,
    NODE_TYPE_ACTOR,
    NODE_TYPE_ENTITY,
    NODE_TYPE_EXCEPTION,
    NODE_TYPE_INPUT,
    NODE_TYPE_POLICY,
    NODE_TYPE_TRACE,
    Edge,
    Node,
)


def make_node_id(node_type: str, identifier: str) -> str:
    """Create node ID in format {node_type}:{identifier}.

    Args:
        node_type: Type of node (trace, entity, etc.)
        identifier: Unique identifier within the type

    Returns:
        Node ID string
    """
    return f"{node_type}:{identifier}"


def make_edge_id(
    edge_type: str, from_node_id: str, to_node_id: str, event_id: str
) -> str:
    """Create edge ID in format {edge_type}:{from_key}:{to_key}:{event_id}.

    Args:
        edge_type: Type of edge
        from_node_id: Source node ID
        to_node_id: Target node ID
        event_id: Event ID that created this edge

    Returns:
        Edge ID string
    """
    return f"{edge_type}:{from_node_id}:{to_node_id}:{event_id}"


@dataclass
class GraphEmission:
    """Container for nodes and edges emitted from an event.

    Attributes:
        nodes: List of nodes to create
        edges: List of edges to create
    """

    nodes: list[Node]
    edges: list[Edge]


class ContextGraphEmitter:
    """Emits nodes and edges from events per SSOT 6.2.4.

    This class transforms each event type into the appropriate
    nodes and edges for the context graph.
    """

    def emit(self, event: StoredEvent) -> GraphEmission:
        """Emit nodes and edges for an event.

        Args:
            event: Stored event to process

        Returns:
            GraphEmission with nodes and edges to create
        """
        event_type = event.event_type
        handlers = {
            EVENT_TYPE_TRACE_STARTED: self._emit_trace_started,
            EVENT_TYPE_INPUT_OBSERVED: self._emit_input_observed,
            EVENT_TYPE_ENTITY_OBSERVED: self._emit_entity_observed,
            EVENT_TYPE_POLICY_EVALUATED: self._emit_policy_evaluated,
            EVENT_TYPE_EXCEPTION_REQUESTED: self._emit_exception_requested,
            EVENT_TYPE_APPROVAL_RECORDED: self._emit_approval_recorded,
            EVENT_TYPE_PRECEDENT_CITED: self._emit_precedent_cited,
            EVENT_TYPE_ACTION_PROPOSED: self._emit_action_proposed,
            EVENT_TYPE_ACTION_COMMITTED: self._emit_action_committed,
            EVENT_TYPE_TRACE_FINISHED: self._emit_trace_finished,
        }

        handler = handlers.get(event_type)
        if handler:
            return handler(event)

        return GraphEmission(nodes=[], edges=[])

    def _emit_trace_started(self, event: StoredEvent) -> GraphEmission:
        """Emit nodes/edges for TraceStarted event.

        Creates:
        - trace node
        - primary entity node + trace_involves_entity edge
        - actor node
        """
        nodes: list[Node] = []
        edges: list[Edge] = []

        # Trace node
        trace_node_id = make_node_id(NODE_TYPE_TRACE, event.trace_id)
        nodes.append(
            Node(
                node_id=trace_node_id,
                node_type=NODE_TYPE_TRACE,
                trace_id=event.trace_id,
                log_seq=event.log_seq,
                created_at=event.occurred_at,
            )
        )

        # Actor node
        actor_id = f"{event.actor.actor_type}:{event.actor.actor_id}"
        actor_node_id = make_node_id(NODE_TYPE_ACTOR, actor_id)
        nodes.append(
            Node(
                node_id=actor_node_id,
                node_type=NODE_TYPE_ACTOR,
                trace_id=event.trace_id,
                log_seq=event.log_seq,
                created_at=event.occurred_at,
            )
        )

        # Primary entity if present
        payload = event.payload
        if "primary_entity" in payload:
            entity = payload["primary_entity"]
            entity_type = entity.get("entity_type", "unknown")
            entity_id = entity.get("entity_id", "unknown")
            full_entity_id = f"{entity_type}:{entity_id}"
            entity_node_id = make_node_id(NODE_TYPE_ENTITY, full_entity_id)

            nodes.append(
                Node(
                    node_id=entity_node_id,
                    node_type=NODE_TYPE_ENTITY,
                    trace_id=event.trace_id,
                    log_seq=event.log_seq,
                    created_at=event.occurred_at,
                )
            )

            edges.append(
                Edge(
                    edge_id=make_edge_id(
                        EDGE_TYPE_TRACE_INVOLVES_ENTITY,
                        trace_node_id,
                        entity_node_id,
                        event.event_id,
                    ),
                    edge_type=EDGE_TYPE_TRACE_INVOLVES_ENTITY,
                    from_node_id=trace_node_id,
                    to_node_id=entity_node_id,
                    trace_id=event.trace_id,
                    log_seq=event.log_seq,
                    created_at=event.occurred_at,
                )
            )

        return GraphEmission(nodes=nodes, edges=edges)

    def _emit_input_observed(self, event: StoredEvent) -> GraphEmission:
        """Emit nodes/edges for InputObserved event.

        Creates:
        - input node
        - trace_observed_input edge
        """
        payload = event.payload
        input_id = payload.get("input_id", event.event_id)

        trace_node_id = make_node_id(NODE_TYPE_TRACE, event.trace_id)
        input_node_id = make_node_id(NODE_TYPE_INPUT, input_id)

        nodes = [
            Node(
                node_id=input_node_id,
                node_type=NODE_TYPE_INPUT,
                trace_id=event.trace_id,
                log_seq=event.log_seq,
                created_at=event.occurred_at,
            )
        ]

        edges = [
            Edge(
                edge_id=make_edge_id(
                    EDGE_TYPE_TRACE_OBSERVED_INPUT,
                    trace_node_id,
                    input_node_id,
                    event.event_id,
                ),
                edge_type=EDGE_TYPE_TRACE_OBSERVED_INPUT,
                from_node_id=trace_node_id,
                to_node_id=input_node_id,
                trace_id=event.trace_id,
                log_seq=event.log_seq,
                created_at=event.occurred_at,
            )
        ]

        return GraphEmission(nodes=nodes, edges=edges)

    def _emit_entity_observed(self, event: StoredEvent) -> GraphEmission:
        """Emit nodes/edges for EntityObserved event.

        Creates:
        - entity node
        - trace_involves_entity edge
        """
        payload = event.payload
        entity = payload.get("entity", {})
        entity_type = entity.get("entity_type", "unknown")
        entity_id = entity.get("entity_id", "unknown")
        full_entity_id = f"{entity_type}:{entity_id}"

        trace_node_id = make_node_id(NODE_TYPE_TRACE, event.trace_id)
        entity_node_id = make_node_id(NODE_TYPE_ENTITY, full_entity_id)

        nodes = [
            Node(
                node_id=entity_node_id,
                node_type=NODE_TYPE_ENTITY,
                trace_id=event.trace_id,
                log_seq=event.log_seq,
                created_at=event.occurred_at,
            )
        ]

        edges = [
            Edge(
                edge_id=make_edge_id(
                    EDGE_TYPE_TRACE_INVOLVES_ENTITY,
                    trace_node_id,
                    entity_node_id,
                    event.event_id,
                ),
                edge_type=EDGE_TYPE_TRACE_INVOLVES_ENTITY,
                from_node_id=trace_node_id,
                to_node_id=entity_node_id,
                trace_id=event.trace_id,
                log_seq=event.log_seq,
                created_at=event.occurred_at,
            )
        ]

        return GraphEmission(nodes=nodes, edges=edges)

    def _emit_policy_evaluated(self, event: StoredEvent) -> GraphEmission:
        """Emit nodes/edges for PolicyEvaluated event.

        Creates:
        - policy node
        - trace_evaluated_policy edge
        """
        payload = event.payload
        policy = payload.get("policy", {})
        policy_id = policy.get("policy_id")
        policy_version = policy.get("policy_version", "")

        # Handle missing policy_id - use event_id as fallback to avoid node collision
        if policy_id is None:
            policy_id = f"unknown:{event.event_id}"

        full_policy_id = f"{policy_id}:{policy_version}" if policy_version else policy_id

        trace_node_id = make_node_id(NODE_TYPE_TRACE, event.trace_id)
        policy_node_id = make_node_id(NODE_TYPE_POLICY, full_policy_id)

        nodes = [
            Node(
                node_id=policy_node_id,
                node_type=NODE_TYPE_POLICY,
                trace_id=event.trace_id,
                log_seq=event.log_seq,
                created_at=event.occurred_at,
            )
        ]

        edges = [
            Edge(
                edge_id=make_edge_id(
                    EDGE_TYPE_TRACE_EVALUATED_POLICY,
                    trace_node_id,
                    policy_node_id,
                    event.event_id,
                ),
                edge_type=EDGE_TYPE_TRACE_EVALUATED_POLICY,
                from_node_id=trace_node_id,
                to_node_id=policy_node_id,
                trace_id=event.trace_id,
                log_seq=event.log_seq,
                created_at=event.occurred_at,
            )
        ]

        return GraphEmission(nodes=nodes, edges=edges)

    def _emit_exception_requested(self, event: StoredEvent) -> GraphEmission:
        """Emit nodes/edges for ExceptionRequested event.

        Creates:
        - exception (pseudo) node
        - trace_requested_exception edge
        """
        payload = event.payload
        exception_id = payload.get("exception_id", event.event_id)

        trace_node_id = make_node_id(NODE_TYPE_TRACE, event.trace_id)
        exception_node_id = make_node_id(NODE_TYPE_EXCEPTION, exception_id)

        nodes = [
            Node(
                node_id=exception_node_id,
                node_type=NODE_TYPE_EXCEPTION,
                trace_id=event.trace_id,
                log_seq=event.log_seq,
                created_at=event.occurred_at,
            )
        ]

        edges = [
            Edge(
                edge_id=make_edge_id(
                    EDGE_TYPE_TRACE_REQUESTED_EXCEPTION,
                    trace_node_id,
                    exception_node_id,
                    event.event_id,
                ),
                edge_type=EDGE_TYPE_TRACE_REQUESTED_EXCEPTION,
                from_node_id=trace_node_id,
                to_node_id=exception_node_id,
                trace_id=event.trace_id,
                log_seq=event.log_seq,
                created_at=event.occurred_at,
            )
        ]

        return GraphEmission(nodes=nodes, edges=edges)

    def _emit_approval_recorded(self, event: StoredEvent) -> GraphEmission:
        """Emit nodes/edges for ApprovalRecorded event.

        Creates:
        - actor node (approver)
        - exception_approved_by edge (if subject is exception)
        """
        payload = event.payload
        subject = payload.get("subject", {})
        subject_type = subject.get("subject_type", "")
        subject_id = subject.get("subject_id", "")

        approver = payload.get("approver", {})
        approver_type = approver.get("actor_type", "person")
        approver_id = approver.get("actor_id", "unknown")
        full_approver_id = f"{approver_type}:{approver_id}"

        nodes: list[Node] = []
        edges: list[Edge] = []

        # Approver actor node
        actor_node_id = make_node_id(NODE_TYPE_ACTOR, full_approver_id)
        nodes.append(
            Node(
                node_id=actor_node_id,
                node_type=NODE_TYPE_ACTOR,
                trace_id=event.trace_id,
                log_seq=event.log_seq,
                created_at=event.occurred_at,
            )
        )

        # If approval is for an exception, create exception_approved_by edge
        if subject_type == "exception" and subject_id:
            exception_node_id = make_node_id(NODE_TYPE_EXCEPTION, subject_id)
            edges.append(
                Edge(
                    edge_id=make_edge_id(
                        EDGE_TYPE_EXCEPTION_APPROVED_BY,
                        exception_node_id,
                        actor_node_id,
                        event.event_id,
                    ),
                    edge_type=EDGE_TYPE_EXCEPTION_APPROVED_BY,
                    from_node_id=exception_node_id,
                    to_node_id=actor_node_id,
                    trace_id=event.trace_id,
                    log_seq=event.log_seq,
                    created_at=event.occurred_at,
                )
            )

        return GraphEmission(nodes=nodes, edges=edges)

    def _emit_precedent_cited(self, event: StoredEvent) -> GraphEmission:
        """Emit nodes/edges for PrecedentCited event.

        Creates:
        - cited trace node (reference)
        - trace_cited_precedent edge
        """
        payload = event.payload
        cited_trace_id = payload.get("cited_trace_id", "")

        if not cited_trace_id:
            return GraphEmission(nodes=[], edges=[])

        trace_node_id = make_node_id(NODE_TYPE_TRACE, event.trace_id)
        cited_trace_node_id = make_node_id(NODE_TYPE_TRACE, cited_trace_id)

        # Note: We don't create a node for the cited trace here
        # as it should already exist from its own TraceStarted event.
        # We only create the edge.
        edges = [
            Edge(
                edge_id=make_edge_id(
                    EDGE_TYPE_TRACE_CITED_PRECEDENT,
                    trace_node_id,
                    cited_trace_node_id,
                    event.event_id,
                ),
                edge_type=EDGE_TYPE_TRACE_CITED_PRECEDENT,
                from_node_id=trace_node_id,
                to_node_id=cited_trace_node_id,
                trace_id=event.trace_id,
                log_seq=event.log_seq,
                created_at=event.occurred_at,
            )
        ]

        return GraphEmission(nodes=[], edges=edges)

    def _emit_action_proposed(self, event: StoredEvent) -> GraphEmission:
        """Emit nodes/edges for ActionProposed event.

        Creates:
        - action (pseudo) node
        - trace_proposed_action edge
        - action_targets_entity edge
        """
        payload = event.payload
        action_id = payload.get("action_id", event.event_id)

        trace_node_id = make_node_id(NODE_TYPE_TRACE, event.trace_id)
        action_node_id = make_node_id(NODE_TYPE_ACTION, action_id)

        nodes = [
            Node(
                node_id=action_node_id,
                node_type=NODE_TYPE_ACTION,
                trace_id=event.trace_id,
                log_seq=event.log_seq,
                created_at=event.occurred_at,
            )
        ]

        edges = [
            Edge(
                edge_id=make_edge_id(
                    EDGE_TYPE_TRACE_PROPOSED_ACTION,
                    trace_node_id,
                    action_node_id,
                    event.event_id,
                ),
                edge_type=EDGE_TYPE_TRACE_PROPOSED_ACTION,
                from_node_id=trace_node_id,
                to_node_id=action_node_id,
                trace_id=event.trace_id,
                log_seq=event.log_seq,
                created_at=event.occurred_at,
            )
        ]

        # action_targets_entity edge
        target_entity = payload.get("target_entity", {})
        if target_entity:
            entity_type = target_entity.get("entity_type", "unknown")
            entity_id = target_entity.get("entity_id", "unknown")
            full_entity_id = f"{entity_type}:{entity_id}"
            entity_node_id = make_node_id(NODE_TYPE_ENTITY, full_entity_id)

            edges.append(
                Edge(
                    edge_id=make_edge_id(
                        EDGE_TYPE_ACTION_TARGETS_ENTITY,
                        action_node_id,
                        entity_node_id,
                        event.event_id,
                    ),
                    edge_type=EDGE_TYPE_ACTION_TARGETS_ENTITY,
                    from_node_id=action_node_id,
                    to_node_id=entity_node_id,
                    trace_id=event.trace_id,
                    log_seq=event.log_seq,
                    created_at=event.occurred_at,
                )
            )

        return GraphEmission(nodes=nodes, edges=edges)

    def _emit_action_committed(self, event: StoredEvent) -> GraphEmission:
        """Emit nodes/edges for ActionCommitted event.

        Creates:
        - trace_committed_action edge
        """
        payload = event.payload
        action_id = payload.get("action_id", "")

        if not action_id:
            return GraphEmission(nodes=[], edges=[])

        trace_node_id = make_node_id(NODE_TYPE_TRACE, event.trace_id)
        action_node_id = make_node_id(NODE_TYPE_ACTION, action_id)

        edges = [
            Edge(
                edge_id=make_edge_id(
                    EDGE_TYPE_TRACE_COMMITTED_ACTION,
                    trace_node_id,
                    action_node_id,
                    event.event_id,
                ),
                edge_type=EDGE_TYPE_TRACE_COMMITTED_ACTION,
                from_node_id=trace_node_id,
                to_node_id=action_node_id,
                trace_id=event.trace_id,
                log_seq=event.log_seq,
                created_at=event.occurred_at,
            )
        ]

        return GraphEmission(nodes=[], edges=edges)

    def _emit_trace_finished(self, _event: StoredEvent) -> GraphEmission:
        """Emit nodes/edges for TraceFinished event.

        TraceFinished doesn't create additional nodes/edges for the context graph.
        It updates the trace summary instead (handled by projector).
        """
        return GraphEmission(nodes=[], edges=[])


__all__ = [
    "ContextGraphEmitter",
    "GraphEmission",
    "make_node_id",
    "make_edge_id",
]
