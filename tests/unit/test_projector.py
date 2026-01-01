"""Tests for projection engine - TC-P3-001 through TC-P3-013."""

import pytest

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
)
from decisiongraph.ids import generate_trace_id
from decisiongraph.projections import (
    ALL_EDGE_TYPES,
    ALL_NODE_TYPES,
    EDGE_TYPE_ACTION_TARGETS_ENTITY,
    EDGE_TYPE_TRACE_EVALUATED_POLICY,
    EDGE_TYPE_TRACE_INVOLVES_ENTITY,
    EDGE_TYPE_TRACE_PROPOSED_ACTION,
    EDGE_TYPE_TRACE_REQUESTED_EXCEPTION,
    NODE_TYPE_ACTION,
    NODE_TYPE_ENTITY,
    NODE_TYPE_EXCEPTION,
    NODE_TYPE_POLICY,
    NODE_TYPE_TRACE,
    ContextGraphEmitter,
    Edge,
    Node,
    make_edge_id,
    make_node_id,
)
from decisiongraph.testing import create_test_envelope


class TestNodeTypes:
    """Tests for node types."""

    def test_all_node_types_count(self) -> None:
        """There are 7 node types."""
        assert len(ALL_NODE_TYPES) == 7

    def test_node_types(self) -> None:
        """Node types are correct."""
        expected = {"trace", "entity", "input", "policy", "exception", "action", "actor"}
        assert ALL_NODE_TYPES == expected


class TestEdgeTypes:
    """Tests for edge types."""

    def test_all_edge_types_count(self) -> None:
        """There are 9 edge types per SSOT 6.2.4."""
        assert len(ALL_EDGE_TYPES) == 9

    def test_edge_types(self) -> None:
        """Edge types are correct."""
        expected = {
            "trace_involves_entity",
            "trace_observed_input",
            "trace_evaluated_policy",
            "trace_requested_exception",
            "exception_approved_by",
            "trace_cited_precedent",
            "trace_proposed_action",
            "trace_committed_action",
            "action_targets_entity",
        }
        assert ALL_EDGE_TYPES == expected


class TestNodeDataclass:
    """Tests for Node dataclass."""

    def test_create_node(self) -> None:
        """Create a valid node."""
        node = Node(
            node_id="trace:abc123",
            node_type=NODE_TYPE_TRACE,
            trace_id="abc123",
            log_seq=1,
            created_at="2026-01-01T00:00:00Z",
        )
        assert node.node_id == "trace:abc123"
        assert node.attrs == {}

    def test_node_id_must_have_colon(self) -> None:
        """Node ID must be in format type:id."""
        with pytest.raises(ValueError, match="must be in format"):
            Node(
                node_id="invalid",
                node_type="trace",
                trace_id="abc",
                log_seq=1,
                created_at="2026-01-01T00:00:00Z",
            )


class TestEdgeDataclass:
    """Tests for Edge dataclass."""

    def test_create_edge(self) -> None:
        """Create a valid edge."""
        edge = Edge(
            edge_id="trace_involves_entity:trace:t1:entity:e1:evt1",
            edge_type=EDGE_TYPE_TRACE_INVOLVES_ENTITY,
            from_node_id="trace:t1",
            to_node_id="entity:e1",
            trace_id="t1",
            log_seq=1,
            created_at="2026-01-01T00:00:00Z",
        )
        assert edge.attrs == {}


class TestMakeNodeId:
    """Tests for make_node_id function."""

    def test_format(self) -> None:
        """TC-P3-006: Node keys match SSOT format."""
        node_id = make_node_id("trace", "abc123")
        assert node_id == "trace:abc123"

    def test_entity_format(self) -> None:
        """Entity nodes include type and id."""
        node_id = make_node_id("entity", "Account:acc-123")
        assert node_id == "entity:Account:acc-123"


class TestMakeEdgeId:
    """Tests for make_edge_id function."""

    def test_format(self) -> None:
        """TC-P3-007: Edge keys match SSOT format."""
        edge_id = make_edge_id(
            "trace_involves_entity",
            "trace:t1",
            "entity:Account:acc-1",
            "evt-123",
        )
        assert edge_id == "trace_involves_entity:trace:t1:entity:Account:acc-1:evt-123"


class TestContextGraphEmitter:
    """Tests for ContextGraphEmitter."""

    def test_emit_trace_started(self) -> None:
        """TraceStarted creates trace node."""
        emitter = ContextGraphEmitter()
        trace_id = generate_trace_id()

        envelope = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={
                "workflow": "renewal",
                "title": "Test",
                "primary_entity": {"entity_type": "Account", "entity_id": "acc-123"},
            },
        )

        # Create mock StoredEvent
        from decisiongraph.testing.fakes import InMemoryEventStore

        store = InMemoryEventStore()
        event = store.append_event(envelope)

        emission = emitter.emit(event)

        # Should have trace node, entity node, actor node
        assert len(emission.nodes) == 3
        node_types = {n.node_type for n in emission.nodes}
        assert NODE_TYPE_TRACE in node_types
        assert NODE_TYPE_ENTITY in node_types

        # Should have trace_involves_entity edge
        assert len(emission.edges) == 1
        assert emission.edges[0].edge_type == EDGE_TYPE_TRACE_INVOLVES_ENTITY

    def test_emit_entity_observed(self) -> None:
        """EntityObserved creates entity node and edge."""
        emitter = ContextGraphEmitter()
        trace_id = generate_trace_id()

        # First create TraceStarted
        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )

        # Then EntityObserved
        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_ENTITY_OBSERVED,
            payload={
                "entity": {"entity_type": "Contact", "entity_id": "cnt-456"},
                "role": "related",
                "facts": [],
            },
        )

        from decisiongraph.testing.fakes import InMemoryEventStore

        store = InMemoryEventStore()
        store.append_event(env0)
        event = store.append_event(env1)

        emission = emitter.emit(event)

        assert len(emission.nodes) == 1
        assert emission.nodes[0].node_type == NODE_TYPE_ENTITY

        assert len(emission.edges) == 1
        assert emission.edges[0].edge_type == EDGE_TYPE_TRACE_INVOLVES_ENTITY

    def test_emit_policy_evaluated(self) -> None:
        """PolicyEvaluated creates policy node and edge."""
        emitter = ContextGraphEmitter()
        trace_id = generate_trace_id()

        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )

        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_POLICY_EVALUATED,
            payload={
                "policy": {"policy_id": "discount-policy", "policy_version": "1.0"},
                "inputs": [],
                "decision": "allow",
            },
        )

        from decisiongraph.testing.fakes import InMemoryEventStore

        store = InMemoryEventStore()
        store.append_event(env0)
        event = store.append_event(env1)

        emission = emitter.emit(event)

        assert len(emission.nodes) == 1
        assert emission.nodes[0].node_type == NODE_TYPE_POLICY

        assert len(emission.edges) == 1
        assert emission.edges[0].edge_type == EDGE_TYPE_TRACE_EVALUATED_POLICY

    def test_emit_exception_requested(self) -> None:
        """TC-P3-008: Exception pseudo node created."""
        emitter = ContextGraphEmitter()
        trace_id = generate_trace_id()

        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )

        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_EXCEPTION_REQUESTED,
            payload={
                "exception_id": "exc-123",
                "policy": {"policy_id": "test", "policy_version": "1.0"},
                "reason": "Customer is strategic partner",
            },
        )

        from decisiongraph.testing.fakes import InMemoryEventStore

        store = InMemoryEventStore()
        store.append_event(env0)
        event = store.append_event(env1)

        emission = emitter.emit(event)

        assert len(emission.nodes) == 1
        assert emission.nodes[0].node_type == NODE_TYPE_EXCEPTION
        assert "exception:exc-123" == emission.nodes[0].node_id

        assert len(emission.edges) == 1
        assert emission.edges[0].edge_type == EDGE_TYPE_TRACE_REQUESTED_EXCEPTION

    def test_emit_action_proposed(self) -> None:
        """TC-P3-009: Action pseudo node created."""
        emitter = ContextGraphEmitter()
        trace_id = generate_trace_id()

        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )

        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_ACTION_PROPOSED,
            payload={
                "action_id": "act-456",
                "action_type": "update",
                "target_entity": {"entity_type": "Account", "entity_id": "acc-123"},
                "target_system": "crm",
                "changes": [],
            },
        )

        from decisiongraph.testing.fakes import InMemoryEventStore

        store = InMemoryEventStore()
        store.append_event(env0)
        event = store.append_event(env1)

        emission = emitter.emit(event)

        assert len(emission.nodes) == 1
        assert emission.nodes[0].node_type == NODE_TYPE_ACTION
        assert "action:act-456" == emission.nodes[0].node_id

        # Should have 2 edges: trace_proposed_action and action_targets_entity
        assert len(emission.edges) == 2
        edge_types = {e.edge_type for e in emission.edges}
        assert EDGE_TYPE_TRACE_PROPOSED_ACTION in edge_types
        assert EDGE_TYPE_ACTION_TARGETS_ENTITY in edge_types

    def test_emit_action_proposed_with_target(self) -> None:
        """TC-P3-011: action_targets_entity edge required."""
        emitter = ContextGraphEmitter()
        trace_id = generate_trace_id()

        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )

        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_ACTION_PROPOSED,
            payload={
                "action_id": "act-456",
                "action_type": "update",
                "target_entity": {"entity_type": "Account", "entity_id": "acc-123"},
                "target_system": "crm",
                "changes": [],
            },
        )

        from decisiongraph.testing.fakes import InMemoryEventStore

        store = InMemoryEventStore()
        store.append_event(env0)
        event = store.append_event(env1)

        emission = emitter.emit(event)

        # Find action_targets_entity edge
        target_edges = [e for e in emission.edges if e.edge_type == EDGE_TYPE_ACTION_TARGETS_ENTITY]
        assert len(target_edges) == 1
        assert target_edges[0].from_node_id == "action:act-456"
        assert "entity:Account:acc-123" == target_edges[0].to_node_id

    def test_emit_trace_finished_no_nodes(self) -> None:
        """TraceFinished doesn't create graph nodes/edges."""
        emitter = ContextGraphEmitter()
        trace_id = generate_trace_id()

        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )

        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_TRACE_FINISHED,
            payload={"outcome": "success"},
        )

        from decisiongraph.testing.fakes import InMemoryEventStore

        store = InMemoryEventStore()
        store.append_event(env0)
        event = store.append_event(env1)

        emission = emitter.emit(event)

        assert len(emission.nodes) == 0
        assert len(emission.edges) == 0


class TestNodeAttrs:
    """Tests for attrs_json requirement."""

    def test_node_attrs_empty_by_default(self) -> None:
        """TC-P3-013: Node attrs are {} by default."""
        node = Node(
            node_id="trace:t1",
            node_type="trace",
            trace_id="t1",
            log_seq=1,
            created_at="2026-01-01T00:00:00Z",
        )
        assert node.attrs == {}

    def test_edge_attrs_empty_by_default(self) -> None:
        """TC-P3-013: Edge attrs are {} by default."""
        edge = Edge(
            edge_id="type:from:to:evt",
            edge_type="type",
            from_node_id="from",
            to_node_id="to",
            trace_id="t1",
            log_seq=1,
            created_at="2026-01-01T00:00:00Z",
        )
        assert edge.attrs == {}
