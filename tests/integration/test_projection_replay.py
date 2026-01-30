"""Integration tests for projection replay - TC-P3-001 through TC-P3-005."""

import pytest

from decisiongraph.domain.events import (
    EVENT_TYPE_ACTION_PROPOSED,
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_EXCEPTION_REQUESTED,
    EVENT_TYPE_POLICY_EVALUATED,
    EVENT_TYPE_PRECEDENT_CITED,
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
)
from decisiongraph.errors import (
    DG_ERR_CONFLICT,
    DG_ERR_EVENT_SEQUENCE_INVALID,
    DecisionGraphError,
)
from decisiongraph.ids import generate_trace_id
from decisiongraph.projections import (
    SQLiteProjector,
    compute_context_graph_digest,
)
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.testing import create_test_envelope


class TestFullReplay:
    """Tests for full event replay."""

    def test_projector_full_replay_builds_graph(self) -> None:
        """TC-P3-001: Full replay creates correct graph."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)

            trace_id = generate_trace_id()

            # Create a full trace
            events = []

            # TraceStarted
            env0 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "renewal",
                    "title": "Customer Renewal",
                    "primary_entity": {"entity_type": "Account", "entity_id": "acc-123"},
                },
            )
            events.append(store.append_event(env0))

            # EntityObserved
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
            events.append(store.append_event(env1))

            # PolicyEvaluated
            env2 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=2,
                event_type=EVENT_TYPE_POLICY_EVALUATED,
                payload={
                    "policy": {"policy_id": "discount-policy", "policy_version": "1.0"},
                    "inputs": [],
                    "decision": "require_exception",
                },
            )
            events.append(store.append_event(env2))

            # ExceptionRequested
            env3 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=3,
                event_type=EVENT_TYPE_EXCEPTION_REQUESTED,
                payload={
                    "exception_id": "exc-789",
                    "policy": {"policy_id": "discount-policy", "policy_version": "1.0"},
                    "reason": "Strategic partner",
                },
            )
            events.append(store.append_event(env3))

            # ActionProposed
            env4 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=4,
                event_type=EVENT_TYPE_ACTION_PROPOSED,
                payload={
                    "action_id": "act-001",
                    "action_type": "update",
                    "target_entity": {"entity_type": "Account", "entity_id": "acc-123"},
                    "target_system": "crm",
                    "changes": [],
                },
            )
            events.append(store.append_event(env4))

            # TraceFinished
            env5 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=5,
                event_type=EVENT_TYPE_TRACE_FINISHED,
                payload={"outcome": "success"},
            )
            events.append(store.append_event(env5))

            # Project all events
            for event in events:
                projector.project_event(event)

            # Verify nodes
            nodes = projector.get_nodes(trace_id)
            node_types = {n["node_type"] for n in nodes}
            assert "trace" in node_types
            assert "entity" in node_types
            assert "policy" in node_types
            assert "exception" in node_types
            assert "action" in node_types
            assert "actor" in node_types

            # Verify edges
            edges = projector.get_edges(trace_id)
            edge_types = {e["edge_type"] for e in edges}
            assert "trace_involves_entity" in edge_types
            assert "trace_evaluated_policy" in edge_types
            assert "trace_requested_exception" in edge_types
            assert "trace_proposed_action" in edge_types
            assert "action_targets_entity" in edge_types

            # Verify trace summary
            summary = projector.get_trace_summary(trace_id)
            assert summary is not None
            assert summary["workflow"] == "renewal"
            assert summary["outcome"] == "success"

    def test_projector_resume_cursor(self) -> None:
        """TC-P3-003: Resume from last_applied_log_seq."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)

            trace_id = generate_trace_id()

            # Create first event
            env0 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
            )
            event0 = store.append_event(env0)
            projector.project_event(event0)

            # Check cursor
            assert projector.get_cursor() == 1

            # Create second event
            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={
                    "entity": {"entity_type": "Test", "entity_id": "t1"},
                    "role": "primary",
                    "facts": [],
                },
            )
            event1 = store.append_event(env1)
            projector.project_event(event1)

            assert projector.get_cursor() == 2

            # Create new projector - should resume from cursor
            projector2 = SQLiteProjector(store.connection)
            assert projector2.get_cursor() == 2


class TestPayloadHashValidation:
    """Tests for payload hash validation during replay."""

    def test_projector_reject_bad_payload_hash(self) -> None:
        """TC-P3-004: Invalid hash rejected."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)

            trace_id = generate_trace_id()

            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
            )
            event = store.append_event(env)

            # Corrupt the payload hash
            from decisiongraph.domain.events import StoredEvent

            corrupted = StoredEvent(
                log_seq=event.log_seq,
                event_id=event.event_id,
                trace_id=event.trace_id,
                trace_seq=event.trace_seq,
                event_type=event.event_type,
                occurred_at=event.occurred_at,
                recorded_at=event.recorded_at,
                source=event.source,
                actor=event.actor,
                idempotency_key=event.idempotency_key,
                payload=event.payload,
                payload_hash="sha256:0000000000000000000000000000000000000000000000000000000000000000",
                correlation_id=event.correlation_id,
                causation_event_id=event.causation_event_id,
                schema_version=event.schema_version,
                tags=event.tags,
            )

            with pytest.raises(DecisionGraphError) as exc_info:
                projector.project_event(corrupted)

            assert exc_info.value.code == DG_ERR_CONFLICT
            assert "hash mismatch" in str(exc_info.value).lower()


class TestTraceSeqValidation:
    """Tests for trace_seq gap detection."""

    def test_projector_reject_trace_seq_gap(self) -> None:
        """TC-P3-005: Sequence gaps rejected."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)

            trace_id = generate_trace_id()

            # Create first event
            env0 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
            )
            event0 = store.append_event(env0)
            projector.project_event(event0)

            # Create event with gap (seq=1 missing, trying seq=2)
            env2 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,  # This gets stored correctly
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={
                    "entity": {"entity_type": "Test", "entity_id": "t1"},
                    "role": "primary",
                    "facts": [],
                },
            )
            event2 = store.append_event(env2)

            # Manually create a gap by modifying the event's trace_seq
            from decisiongraph.domain.events import StoredEvent

            gapped = StoredEvent(
                log_seq=event2.log_seq,
                event_id=event2.event_id,
                trace_id=event2.trace_id,
                trace_seq=5,  # Gap! Expected 1
                event_type=event2.event_type,
                occurred_at=event2.occurred_at,
                recorded_at=event2.recorded_at,
                source=event2.source,
                actor=event2.actor,
                idempotency_key=event2.idempotency_key,
                payload=event2.payload,
                payload_hash=event2.payload_hash,
                correlation_id=event2.correlation_id,
                causation_event_id=event2.causation_event_id,
                schema_version=event2.schema_version,
                tags=event2.tags,
            )

            with pytest.raises(DecisionGraphError) as exc_info:
                projector.project_event(gapped)

            assert exc_info.value.code == DG_ERR_EVENT_SEQUENCE_INVALID

    def test_projector_resume_trace_seq_after_restart(self) -> None:
        """Projector resumes trace_seq tracking after restart."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            env0 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
            )
            event0 = store.append_event(env0)
            projector.project_event(event0)

            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={
                    "entity": {"entity_type": "Test", "entity_id": "t1"},
                    "role": "primary",
                    "facts": [],
                },
            )
            event1 = store.append_event(env1)
            projector.project_event(event1)

            # New projector simulates process restart
            projector2 = SQLiteProjector(store.connection)

            env2 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=2,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={
                    "entity": {"entity_type": "Test", "entity_id": "t2"},
                    "role": "primary",
                    "facts": [],
                },
            )
            event2 = store.append_event(env2)

            # Should not raise gap error
            projector2.project_event(event2)


class TestTraceSummary:
    """Tests for trace summary projection."""

    def test_trace_summary_created_on_start(self) -> None:
        """Trace summary created on TraceStarted."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)

            trace_id = generate_trace_id()

            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "renewal",
                    "title": "Test Renewal",
                    "primary_entity": {"entity_type": "Account", "entity_id": "acc-1"},
                },
            )
            event = store.append_event(env)
            projector.project_event(event)

            summary = projector.get_trace_summary(trace_id)
            assert summary is not None
            assert summary["workflow"] == "renewal"
            assert summary["title"] == "Test Renewal"
            assert summary["outcome"] is None  # Not finished yet

    def test_trace_summary_updated_on_finish(self) -> None:
        """Trace summary updated on TraceFinished."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)

            trace_id = generate_trace_id()

            env0 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
            )
            event0 = store.append_event(env0)
            projector.project_event(event0)

            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_TRACE_FINISHED,
                payload={"outcome": "failure", "summary": "Policy violation"},
            )
            event1 = store.append_event(env1)
            projector.project_event(event1)

            summary = projector.get_trace_summary(trace_id)
            assert summary is not None
            assert summary["outcome"] == "failure"
            assert summary["finished_at"] is not None


class TestPrecedentIndex:
    """Tests for precedent index projection."""

    def test_precedent_index_on_cite(self) -> None:
        """Precedent index created for PrecedentCited events."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)

            # Create cited trace first
            cited_trace_id = generate_trace_id()
            env_cited = create_test_envelope(
                trace_id=cited_trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Previous Decision"},
            )
            store.append_event(env_cited)

            # Create current trace
            trace_id = generate_trace_id()

            env0 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Current Decision"},
            )
            event0 = store.append_event(env0)
            projector.project_event(event0)

            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_PRECEDENT_CITED,
                payload={
                    "cited_trace_id": cited_trace_id,
                    "reason": "Similar customer situation",
                    "similarity_score": "0.95",
                },
            )
            event1 = store.append_event(env1)
            projector.project_event(event1)

            env2 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=2,
                event_type=EVENT_TYPE_TRACE_FINISHED,
                payload={"outcome": "success"},
            )
            event2 = store.append_event(env2)
            projector.project_event(event2)

            # Check precedent index
            cursor = store.connection.execute(
                "SELECT * FROM dg_precedent_index WHERE trace_id = ?",
                (trace_id,),
            )
            rows = cursor.fetchall()
            assert len(rows) == 1
            assert rows[0]["cited_trace_id"] == cited_trace_id


class TestSubgraphOrdering:
    """Tests for deterministic ordering."""

    def test_subgraph_ordering(self) -> None:
        """TC-P3-010: Nodes/edges ordered correctly."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)

            trace_id = generate_trace_id()

            # Create events
            env0 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "test",
                    "title": "Test",
                    "primary_entity": {"entity_type": "Account", "entity_id": "acc-1"},
                },
            )
            event0 = store.append_event(env0)
            projector.project_event(event0)

            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={
                    "entity": {"entity_type": "Contact", "entity_id": "cnt-1"},
                    "role": "related",
                    "facts": [],
                },
            )
            event1 = store.append_event(env1)
            projector.project_event(event1)

            # Get nodes - should be sorted by node_id
            nodes = projector.get_nodes(trace_id)
            node_ids = [n["node_id"] for n in nodes]
            assert node_ids == sorted(node_ids)

            # Get edges - should be sorted by edge_id
            edges = projector.get_edges(trace_id)
            edge_ids = [e["edge_id"] for e in edges]
            assert edge_ids == sorted(edge_ids)


class TestRebuild:
    """Tests for projection rebuild."""

    def test_rebuild_clears_and_replays(self) -> None:
        """Rebuild clears existing projections."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)

            trace_id = generate_trace_id()

            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
            )
            event = store.append_event(env)
            projector.project_event(event)

            assert len(projector.get_nodes()) > 0

            # Rebuild clears
            projector.rebuild()
            assert len(projector.get_nodes()) == 0
            assert projector.get_cursor() == 0

    def test_digest_stable_after_rebuild(self) -> None:
        """Digest is stable after rebuild."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)

            trace_id = generate_trace_id()

            events = []
            env0 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
            )
            events.append(store.append_event(env0))

            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_TRACE_FINISHED,
                payload={"outcome": "success"},
            )
            events.append(store.append_event(env1))

            # Project
            for event in events:
                projector.project_event(event)
            digest1 = compute_context_graph_digest(store.connection)

            # Rebuild and re-project
            projector.rebuild()
            for event in events:
                projector.project_event(event)
            digest2 = compute_context_graph_digest(store.connection)

            assert digest1 == digest2
