"""Integration tests for event and graph queries per SSOT 8.1 (TC-P5-001 through TC-P5-009).

This module tests:
- Event queries (list_events, get_trace_events, get_trace_summary)
- Graph queries (get_context_subgraph, list_node_edges)
- Query ordering and determinism
- Staleness checks
"""

import pytest

from decisiongraph.domain.events import (
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_POLICY_EVALUATED,
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
)
from decisiongraph.errors import (
    DG_ERR_INVALID_ARGUMENT,
    DG_ERR_NOT_FOUND,
    DG_ERR_PROJECTION_OUT_OF_DATE,
    DecisionGraphError,
)
from decisiongraph.ids import generate_trace_id
from decisiongraph.projections import SQLiteProjector
from decisiongraph.query import (
    NodeRef,
    PrecedentQuery,
    find_precedents,
    get_context_subgraph,
    get_trace_events,
    get_trace_summary,
    list_events,
    list_node_edges,
)
from decisiongraph.query.filters import GraphFilter
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.testing import create_test_envelope


class TestEventQueries:
    """Test event query functions."""

    def test_list_events_by_type(self) -> None:
        """TC-P5-001: list_events filters by event_type correctly."""
        with SQLiteEventStore(":memory:") as store:
            trace_id = generate_trace_id()

            # Create events of different types
            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "test",
                    "title": "Test",
                    "primary_entity": {"entity_type": "Account", "entity_id": "acc-1"},
                },
            )
            store.append_event(env1)

            env2 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={
                    "entity": {"entity_type": "Contact", "entity_id": "cnt-1"},
                    "role": "related",
                    "facts": [],
                },
            )
            store.append_event(env2)

            # Query by type
            started_events = list_events(store, event_type=EVENT_TYPE_TRACE_STARTED)
            assert len(started_events) == 1
            assert started_events[0].event_type == EVENT_TYPE_TRACE_STARTED

            entity_events = list_events(store, event_type=EVENT_TYPE_ENTITY_OBSERVED)
            assert len(entity_events) == 1
            assert entity_events[0].event_type == EVENT_TYPE_ENTITY_OBSERVED

    def test_list_events_by_trace(self) -> None:
        """TC-P5-002: list_events can filter by trace_id via store."""
        with SQLiteEventStore(":memory:") as store:
            trace1 = generate_trace_id()
            trace2 = generate_trace_id()

            # Create events in different traces
            env1 = create_test_envelope(
                trace_id=trace1,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "test1",
                    "title": "Test 1",
                    "primary_entity": {"entity_type": "Account", "entity_id": "acc-1"},
                },
            )
            store.append_event(env1)

            env2 = create_test_envelope(
                trace_id=trace2,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "test2",
                    "title": "Test 2",
                    "primary_entity": {"entity_type": "Account", "entity_id": "acc-2"},
                },
            )
            store.append_event(env2)

            # Query all events
            all_events = list_events(store)
            assert len(all_events) == 2

            # Query by trace_id using get_trace_events
            trace1_events = get_trace_events(store, trace1)
            assert len(trace1_events) == 1
            assert trace1_events[0].trace_id == trace1

    def test_list_events_by_log_seq_range(self) -> None:
        """TC-P5-003: list_events filters by log_seq range correctly."""
        with SQLiteEventStore(":memory:") as store:
            trace_id = generate_trace_id()

            # Create multiple events
            for i in range(5):
                env = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=i,
                    event_type=EVENT_TYPE_TRACE_STARTED
                    if i == 0
                    else EVENT_TYPE_ENTITY_OBSERVED,
                    payload={
                        "workflow": "test",
                        "title": f"Test {i}",
                        "primary_entity": {
                            "entity_type": "Account",
                            "entity_id": f"acc-{i}",
                        },
                    }
                    if i == 0
                    else {
                        "entity": {"entity_type": "Contact", "entity_id": f"cnt-{i}"},
                        "role": "related",
                        "facts": [],
                    },
                )
                store.append_event(env)

            # Query with range
            events = list_events(store, since_log_seq=2, until_log_seq=4)
            assert len(events) == 2
            assert events[0].log_seq == 3
            assert events[1].log_seq == 4

    def test_trace_summary_unfinished(self) -> None:
        """TC-P5-004: get_trace_summary for unfinished trace returns null outcome."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "test",
                    "title": "Test Trace",
                    "primary_entity": {"entity_type": "Account", "entity_id": "acc-1"},
                },
            )
            event = store.append_event(env)
            projector.project_event(event)

            summary = get_trace_summary(store, projector, trace_id)
            assert summary.trace_id == trace_id
            assert summary.workflow == "test"
            assert summary.outcome is None
            assert summary.finished_at is None

    def test_trace_summary_finished(self) -> None:
        """TC-P5-005: get_trace_summary for finished trace returns outcome."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            # Start trace
            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "test",
                    "title": "Test Trace",
                    "primary_entity": {"entity_type": "Account", "entity_id": "acc-1"},
                },
            )
            event1 = store.append_event(env1)
            projector.project_event(event1)

            # Finish trace
            env2 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_TRACE_FINISHED,
                payload={"outcome": "approved", "summary": "All good"},
            )
            event2 = store.append_event(env2)
            projector.project_event(event2)

            summary = get_trace_summary(store, projector, trace_id)
            assert summary.trace_id == trace_id
            assert summary.outcome == "approved"
            assert summary.finished_at is not None

    def test_trace_events_pagination(self) -> None:
        """TC-P5-006: get_trace_events supports pagination with since_trace_seq and limit."""
        with SQLiteEventStore(":memory:") as store:
            trace_id = generate_trace_id()

            # Create multiple events in a trace
            for i in range(10):
                env = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=i,
                    event_type=EVENT_TYPE_TRACE_STARTED
                    if i == 0
                    else EVENT_TYPE_ENTITY_OBSERVED,
                    payload={
                        "workflow": "test",
                        "title": f"Event {i}",
                        "primary_entity": {
                            "entity_type": "Account",
                            "entity_id": f"acc-{i}",
                        },
                    }
                    if i == 0
                    else {
                        "entity": {"entity_type": "Contact", "entity_id": f"cnt-{i}"},
                        "role": "related",
                        "facts": [],
                    },
                )
                store.append_event(env)

            # Get first page
            page1 = get_trace_events(store, trace_id, limit=5)
            assert len(page1) == 5
            assert page1[0].trace_seq == 0
            assert page1[4].trace_seq == 4

            # Get second page
            page2 = get_trace_events(store, trace_id, since_trace_seq=4, limit=5)
            assert len(page2) == 5
            assert page2[0].trace_seq == 5
            assert page2[4].trace_seq == 9

    def test_trace_not_found(self) -> None:
        """Test that querying non-existent trace raises DG_ERR_NOT_FOUND."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)

            with pytest.raises(DecisionGraphError) as exc_info:
                get_trace_summary(store, projector, "non-existent-trace")
            assert exc_info.value.code == DG_ERR_NOT_FOUND

            with pytest.raises(DecisionGraphError) as exc_info:
                get_trace_events(store, "non-existent-trace")
            assert exc_info.value.code == DG_ERR_NOT_FOUND

    def test_invalid_argument_errors(self) -> None:
        """Test that invalid arguments raise DG_ERR_INVALID_ARGUMENT."""
        with SQLiteEventStore(":memory:") as store:
            # since_log_seq > until_log_seq
            with pytest.raises(DecisionGraphError) as exc_info:
                list_events(store, since_log_seq=10, until_log_seq=5)
            assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT

            # limit too large
            with pytest.raises(DecisionGraphError) as exc_info:
                list_events(store, limit=10001)
            assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT


class TestGraphQueries:
    """Test graph query functions."""

    def test_subgraph_depth_0_center_only(self) -> None:
        """TC-P5-007: get_context_subgraph with depth=0 returns only center node."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            # Create a trace with entities
            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "test",
                    "title": "Test",
                    "primary_entity": {"entity_type": "Account", "entity_id": "acc-1"},
                },
            )
            event1 = store.append_event(env1)
            projector.project_event(event1)

            env2 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={
                    "entity": {"entity_type": "Contact", "entity_id": "cnt-1"},
                    "role": "related",
                    "facts": [],
                },
            )
            event2 = store.append_event(env2)
            projector.project_event(event2)

            # Query with depth=0
            center = NodeRef(node_type="trace", node_id=trace_id)
            subgraph = get_context_subgraph(store, projector, center, max_depth=0)

            # Should only include the center node
            assert len(subgraph.nodes) == 1
            assert subgraph.nodes[0].node_id == f"trace:{trace_id}"
            assert len(subgraph.edges) == 0

    def test_subgraph_filter_edge_node_type(self) -> None:
        """TC-P5-008: get_context_subgraph filters by edge_types and node_types."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            # Create trace with entity and policy
            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "test",
                    "title": "Test",
                    "primary_entity": {"entity_type": "Account", "entity_id": "acc-1"},
                },
            )
            event1 = store.append_event(env1)
            projector.project_event(event1)

            env2 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_POLICY_EVALUATED,
                payload={
                    "policy": {"policy_id": "pol-1", "policy_version": "1.0"},
                    "inputs": [],
                    "decision": "allow",
                },
            )
            event2 = store.append_event(env2)
            projector.project_event(event2)

            # Query with filter for policy nodes only
            center = NodeRef(node_type="trace", node_id=trace_id)
            filter_opts = GraphFilter(node_types=["policy"], max_depth=1)
            subgraph = get_context_subgraph(store, projector, center, filter_opts=filter_opts)

            # Should include trace and policy nodes, but not entity
            policy_nodes = [n for n in subgraph.nodes if n.node_type == "policy"]
            assert len(policy_nodes) >= 1

    def test_node_edges_pagination_cursor(self) -> None:
        """TC-P5-009: list_node_edges supports cursor-based pagination."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            # Create trace with multiple entities
            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "test",
                    "title": "Test",
                    "primary_entity": {"entity_type": "Account", "entity_id": "acc-1"},
                },
            )
            event1 = store.append_event(env1)
            projector.project_event(event1)

            for i in range(5):
                env = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=i + 1,
                    event_type=EVENT_TYPE_ENTITY_OBSERVED,
                    payload={
                        "entity": {"entity_type": "Contact", "entity_id": f"cnt-{i}"},
                        "role": "related",
                        "facts": [],
                    },
                )
                event = store.append_event(env)
                projector.project_event(event)

            # Query with pagination
            center = NodeRef(node_type="trace", node_id=trace_id)
            page1 = list_node_edges(store, projector, center, limit=3)

            assert len(page1.edges) == 3
            assert page1.next_cursor is not None

            # Get next page
            page2 = list_node_edges(store, projector, center, cursor=page1.next_cursor, limit=3)
            assert len(page2.edges) >= 1


class TestStalenessChecks:
    """Test projection staleness detection."""

    def test_projection_out_of_date_error(self) -> None:
        """TC-P5-012: Projection-backed queries raise error when projections are stale."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            # Create and project an event
            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "test",
                    "title": "Test",
                    "primary_entity": {"entity_type": "Account", "entity_id": "acc-1"},
                },
            )
            event1 = store.append_event(env1)
            projector.project_event(event1)

            # Add another event but DON'T project it
            env2 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={
                    "entity": {"entity_type": "Contact", "entity_id": "cnt-1"},
                    "role": "related",
                    "facts": [],
                },
            )
            store.append_event(env2)

            # Now projections are stale - should raise error
            center = NodeRef(node_type="trace", node_id=trace_id)
            with pytest.raises(DecisionGraphError) as exc_info:
                get_context_subgraph(store, projector, center)
            assert exc_info.value.code == DG_ERR_PROJECTION_OUT_OF_DATE

            with pytest.raises(DecisionGraphError) as exc_info:
                list_node_edges(store, projector, center)
            assert exc_info.value.code == DG_ERR_PROJECTION_OUT_OF_DATE

            with pytest.raises(DecisionGraphError) as exc_info:
                find_precedents(store, projector, PrecedentQuery())
            assert exc_info.value.code == DG_ERR_PROJECTION_OUT_OF_DATE

    def test_event_queries_bypass_staleness_check(self) -> None:
        """Test that event-log-only queries work even when projections are stale."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            # Create and project an event
            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "test",
                    "title": "Test",
                    "primary_entity": {"entity_type": "Account", "entity_id": "acc-1"},
                },
            )
            event1 = store.append_event(env1)
            projector.project_event(event1)

            # Add another event but DON'T project it
            env2 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={
                    "entity": {"entity_type": "Contact", "entity_id": "cnt-1"},
                    "role": "related",
                    "facts": [],
                },
            )
            store.append_event(env2)

            # Event queries should still work
            events = list_events(store)
            assert len(events) == 2

            trace_events = get_trace_events(store, trace_id)
            assert len(trace_events) == 2
