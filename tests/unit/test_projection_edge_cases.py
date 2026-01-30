"""Tests for projection edge cases.

Covers:
- Payload hash verification during projection
- Trace sequence gap detection
- Empty payload handling
- Context graph emission edge cases
- Projection rebuild behavior
- Cursor tracking
"""

import pytest

from decisiongraph.domain.events import (
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_POLICY_EVALUATED,
    EVENT_TYPE_PRECEDENT_CITED,
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
    StoredEvent,
)
from decisiongraph.domain.types import ActorRef, SourceRef
from decisiongraph.errors import (
    DG_ERR_CONFLICT,
    DG_ERR_EVENT_SEQUENCE_INVALID,
    DG_ERR_SCHEMA_VIOLATION,
    DecisionGraphError,
)
from decisiongraph.ids import generate_event_id, generate_trace_id
from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.serialization import compute_payload_hash
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.time import now_rfc3339


def create_stored_event(
    trace_id: str,
    trace_seq: int,
    event_type: str,
    payload: dict,
    log_seq: int,
) -> StoredEvent:
    """Helper to create StoredEvent for projection tests."""
    return StoredEvent(
        log_seq=log_seq,
        event_id=generate_event_id(),
        trace_id=trace_id,
        trace_seq=trace_seq,
        event_type=event_type,
        occurred_at=now_rfc3339(),
        recorded_at=now_rfc3339(),
        source=SourceRef(producer_id="test", system="test"),
        actor=ActorRef(actor_type="agent", actor_id="test"),
        idempotency_key=f"{trace_id}-{trace_seq}",
        payload=payload,
        payload_hash=compute_payload_hash(payload),
        correlation_id=None,
        causation_event_id=None,
        schema_version="1.0.0",
        tags=[],
    )


class TestPayloadHashVerification:
    """Tests for payload hash verification during projection."""

    def test_mismatched_hash_raises_error(self) -> None:
        """Projection fails if payload_hash doesn't match payload."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()
            payload = {"workflow": "test", "title": "Test"}

            # Create event with wrong hash
            event = StoredEvent(
                log_seq=1,
                event_id=generate_event_id(),
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                occurred_at=now_rfc3339(),
                recorded_at=now_rfc3339(),
                source=SourceRef(producer_id="test", system="test"),
                actor=ActorRef(actor_type="agent", actor_id="test"),
                idempotency_key=f"{trace_id}-0",
                payload=payload,
                payload_hash="sha256:wrong_hash_here",  # Wrong!
                correlation_id=None,
                causation_event_id=None,
                schema_version="1.0.0",
                tags=[],
            )

            with pytest.raises(DecisionGraphError) as exc_info:
                projector.project_event(event)

            assert exc_info.value.code == DG_ERR_CONFLICT
            assert "hash mismatch" in str(exc_info.value).lower()

    def test_correct_hash_passes(self) -> None:
        """Projection succeeds with correct payload hash."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()
            payload = {"workflow": "test", "title": "Test"}

            event = create_stored_event(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload=payload,
                log_seq=1,
            )

            # Should not raise
            projector.project_event(event)


class TestTraceSeqGapDetection:
    """Tests for trace_seq gap detection during projection."""

    def test_projection_detects_trace_seq_gap(self) -> None:
        """Projection fails if trace_seq has gaps."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            # Project first event
            event0 = create_stored_event(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
                log_seq=1,
            )
            projector.project_event(event0)

            # Try to project event with trace_seq=2 (skipping 1)
            event2 = create_stored_event(
                trace_id=trace_id,
                trace_seq=2,  # Gap!
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={"entity": {"entity_type": "Test", "entity_id": "1"}},
                log_seq=2,
            )

            with pytest.raises(DecisionGraphError) as exc_info:
                projector.project_event(event2)

            assert exc_info.value.code == DG_ERR_EVENT_SEQUENCE_INVALID
            assert "gap" in str(exc_info.value).lower()

    def test_multiple_traces_independent_tracking(self) -> None:
        """Each trace has independent trace_seq tracking in projector."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id1 = generate_trace_id()
            trace_id2 = generate_trace_id()

            # Start first trace
            event1_0 = create_stored_event(
                trace_id=trace_id1,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Trace 1"},
                log_seq=1,
            )
            projector.project_event(event1_0)

            # Start second trace
            event2_0 = create_stored_event(
                trace_id=trace_id2,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Trace 2"},
                log_seq=2,
            )
            projector.project_event(event2_0)

            # Add to first trace
            event1_1 = create_stored_event(
                trace_id=trace_id1,
                trace_seq=1,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={"entity": {"entity_type": "Test", "entity_id": "1"}},
                log_seq=3,
            )
            projector.project_event(event1_1)

            # Add to second trace - should work
            event2_1 = create_stored_event(
                trace_id=trace_id2,
                trace_seq=1,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={"entity": {"entity_type": "Test", "entity_id": "2"}},
                log_seq=4,
            )
            projector.project_event(event2_1)  # Should not raise


class TestContextGraphEmission:
    """Tests for context graph emission edge cases."""

    def test_trace_started_creates_trace_node(self) -> None:
        """TraceStarted creates trace node in context graph."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            event = create_stored_event(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "renewal", "title": "Test"},
                log_seq=1,
            )
            projector.project_event(event)

            nodes = projector.get_nodes(trace_id)
            assert len(nodes) >= 1
            # Find trace node
            trace_nodes = [n for n in nodes if n["node_type"] == "trace"]
            assert len(trace_nodes) == 1
            assert trace_nodes[0]["node_id"] == f"trace:{trace_id}"

    def test_entity_observed_creates_entity_node(self) -> None:
        """EntityObserved creates entity node in context graph."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            # Start trace
            event0 = create_stored_event(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
                log_seq=1,
            )
            projector.project_event(event0)

            # Observe entity
            event1 = create_stored_event(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={
                    "entity": {
                        "entity_type": "Contract",
                        "entity_id": "C-123",
                        "system": "sales",
                    }
                },
                log_seq=2,
            )
            projector.project_event(event1)

            nodes = projector.get_nodes(trace_id)
            entity_nodes = [n for n in nodes if n["node_type"] == "entity"]
            assert len(entity_nodes) >= 1

    def test_policy_evaluated_creates_policy_node(self) -> None:
        """PolicyEvaluated creates policy node in context graph."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            # Start trace
            event0 = create_stored_event(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
                log_seq=1,
            )
            projector.project_event(event0)

            # Evaluate policy
            event1 = create_stored_event(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_POLICY_EVALUATED,
                payload={
                    "policy": {
                        "policy_id": "renewal-approval",
                        "policy_version": "1.0.0",
                    },
                    "outcome": "approved",
                    "inputs": {"amount": 1000},
                    "outputs": {"decision": "approve"},
                },
                log_seq=2,
            )
            projector.project_event(event1)

            nodes = projector.get_nodes(trace_id)
            policy_nodes = [n for n in nodes if n["node_type"] == "policy"]
            assert len(policy_nodes) == 1

    def test_missing_policy_id_rejected(self) -> None:
        """PolicyEvaluated without policy_id is rejected."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            # Start trace
            event0 = create_stored_event(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
                log_seq=1,
            )
            projector.project_event(event0)

            # Policy without policy_id
            event1 = create_stored_event(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_POLICY_EVALUATED,
                payload={
                    "policy": {"policy_version": "1.0.0"},  # No policy_id!
                    "outcome": "approved",
                    "inputs": {},
                    "outputs": {},
                },
                log_seq=2,
            )
            with pytest.raises(DecisionGraphError) as exc_info:
                projector.project_event(event1)

            assert exc_info.value.code == DG_ERR_SCHEMA_VIOLATION


class TestProjectionRebuild:
    """Tests for projection rebuild functionality."""

    def test_rebuild_clears_all_projections(self) -> None:
        """rebuild() clears all projection tables."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            # Project some events
            event0 = create_stored_event(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
                log_seq=1,
            )
            projector.project_event(event0)

            assert len(projector.get_nodes()) > 0
            assert projector.get_cursor() > 0

            # Rebuild
            projector.rebuild()

            # All cleared
            assert len(projector.get_nodes()) == 0
            assert len(projector.get_edges()) == 0
            assert projector.get_cursor() == 0

    def test_rebuild_resets_trace_seq_tracker(self) -> None:
        """rebuild() resets trace_seq tracker."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            # Project event
            event0 = create_stored_event(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
                log_seq=1,
            )
            projector.project_event(event0)

            # Rebuild
            projector.rebuild()

            # Should be able to project same trace_seq=0 again
            event0_again = create_stored_event(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
                log_seq=1,
            )
            projector.project_event(event0_again)  # Should not raise


class TestCursorTracking:
    """Tests for projection cursor tracking."""

    def test_cursor_updates_after_projection(self) -> None:
        """Cursor updates after each projected event."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            assert projector.get_cursor() == 0

            event = create_stored_event(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
                log_seq=5,
            )
            projector.project_event(event)

            assert projector.get_cursor() == 5

    def test_cursor_persists_after_reload(self) -> None:
        """Cursor value persists and loads on new projector instance."""
        import tempfile
        from pathlib import Path

        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
            db_path = f.name

        try:
            # First session - project events
            with SQLiteEventStore(db_path) as store:
                projector = SQLiteProjector(store.connection)
                trace_id = generate_trace_id()

                event = create_stored_event(
                    trace_id=trace_id,
                    trace_seq=0,
                    event_type=EVENT_TYPE_TRACE_STARTED,
                    payload={"workflow": "test", "title": "Test"},
                    log_seq=10,
                )
                projector.project_event(event)
                assert projector.get_cursor() == 10

            # Second session - cursor should be loaded
            with SQLiteEventStore(db_path) as store:
                projector2 = SQLiteProjector(store.connection)
                assert projector2.get_cursor() == 10

        finally:
            Path(db_path).unlink(missing_ok=True)


class TestTraceSummary:
    """Tests for trace summary projection."""

    def test_trace_started_creates_summary(self) -> None:
        """TraceStarted creates trace summary entry."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            event = create_stored_event(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "renewal",
                    "title": "Process renewal",
                    "primary_entity": {
                        "entity_type": "Contract",
                        "entity_id": "C-123",
                    },
                },
                log_seq=1,
            )
            projector.project_event(event)

            summary = projector.get_trace_summary(trace_id)
            assert summary is not None
            assert summary["workflow"] == "renewal"
            assert summary["title"] == "Process renewal"
            assert summary["primary_entity_type"] == "Contract"
            assert summary["primary_entity_id"] == "C-123"
            assert summary["outcome"] is None  # Not finished yet

    def test_trace_finished_updates_summary(self) -> None:
        """TraceFinished updates trace summary with outcome."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            # Start
            event0 = create_stored_event(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
                log_seq=1,
            )
            projector.project_event(event0)

            # Finish
            event1 = create_stored_event(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_TRACE_FINISHED,
                payload={"outcome": "success"},
                log_seq=2,
            )
            projector.project_event(event1)

            summary = projector.get_trace_summary(trace_id)
            assert summary["outcome"] == "success"
            assert summary["finished_at"] is not None

    def test_nonexistent_trace_returns_none(self) -> None:
        """get_trace_summary returns None for nonexistent trace."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            summary = projector.get_trace_summary("nonexistent")
            assert summary is None


class TestPrecedentIndex:
    """Tests for precedent index projection."""

    def test_precedent_cited_indexed_on_finish(self) -> None:
        """PrecedentCited events indexed when trace finishes."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()
            cited_trace_id = generate_trace_id()

            # Start
            event0 = create_stored_event(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
                log_seq=1,
            )
            # Cite precedent (similarity_score as string to avoid float)
            event1 = create_stored_event(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_PRECEDENT_CITED,
                payload={
                    "cited_trace_id": cited_trace_id,
                    "reason": "Similar case",
                    "similarity_score": "0.9",  # String, not float
                },
                log_seq=2,
            )
            # Finish
            event2 = create_stored_event(
                trace_id=trace_id,
                trace_seq=2,
                event_type=EVENT_TYPE_TRACE_FINISHED,
                payload={"outcome": "success"},
                log_seq=3,
            )

            # Store events in SQLite for precedent index query
            for event in [event0, event1, event2]:
                store.connection.execute(
                    """
                    INSERT INTO dg_event_log (
                        log_seq, event_id, trace_id, trace_seq, event_type,
                        occurred_at, recorded_at, producer_id, system, subsystem,
                        actor_type, actor_id, idempotency_key, schema_version,
                        payload_json, payload_hash, tags_json
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        event.log_seq,
                        event.event_id,
                        event.trace_id,
                        event.trace_seq,
                        event.event_type,
                        event.occurred_at,
                        event.recorded_at,
                        event.source.producer_id,
                        event.source.system,
                        event.source.subsystem,
                        event.actor.actor_type,
                        event.actor.actor_id,
                        event.idempotency_key,
                        event.schema_version,
                        __import__("json").dumps(event.payload),
                        event.payload_hash,
                        "[]",
                    ),
                )
            store.connection.commit()

            # Project events
            projector.project_event(event0)
            projector.project_event(event1)
            projector.project_event(event2)

            # Check precedent index
            cursor = store.connection.execute(
                "SELECT * FROM dg_precedent_index WHERE trace_id = ?",
                (trace_id,),
            )
            rows = cursor.fetchall()
            assert len(rows) == 1
            assert rows[0]["cited_trace_id"] == cited_trace_id
            assert rows[0]["reason"] == "Similar case"
