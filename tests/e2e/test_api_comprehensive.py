"""Comprehensive tests for DecisionGraph API.

Covers:
- Complete workflow scenarios
- Error handling paths
- Idempotency behavior
- Context manager behavior
- Query integration
- State transitions
"""

import tempfile
from pathlib import Path

import pytest

from decisiongraph.api import DecisionGraph
from decisiongraph.domain.events import EVENT_TYPE_ENTITY_OBSERVED
from decisiongraph.domain.types import (
    ActorRef,
    ApprovalSubject,
    Change,
    EntityRef,
    Fact,
    PolicyRef,
    SourceObjectRef,
    SourceRef,
    Value,
)
from decisiongraph.errors import (
    DG_ERR_INVALID_ARGUMENT,
    DG_ERR_PII_POLICY_VIOLATION,
    DecisionGraphError,
)
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.testing import create_test_envelope


@pytest.fixture
def db_path() -> str:
    """Provide a temporary database path."""
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        path = f.name
    yield path
    Path(path).unlink(missing_ok=True)


@pytest.fixture
def source() -> SourceRef:
    """Provide a test SourceRef."""
    return SourceRef(producer_id="test-api", system="test-system")


@pytest.fixture
def actor() -> ActorRef:
    """Provide a test ActorRef."""
    return ActorRef(actor_type="agent", actor_id="test-agent")


@pytest.fixture
def entity() -> EntityRef:
    """Provide a test EntityRef."""
    return EntityRef(entity_type="Contract", entity_id="C-123", system="sales")


class TestBasicWorkflow:
    """Tests for basic workflow scenarios."""

    def test_start_and_finish_trace(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """Complete workflow: start and finish trace."""
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="renewal",
                title="Test Renewal",
                primary_entity=entity,
                source=source,
                actor=actor,
            )

            assert trace_id is not None
            assert not dg.is_trace_finished(trace_id)

            dg.finish_trace(
                trace_id=trace_id,
                outcome="success",
                source=source,
                actor=actor,
            )

            assert dg.is_trace_finished(trace_id)

    def test_start_with_explicit_trace_id(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """Start trace with explicit trace_id."""
        explicit_id = "trace-explicit-12345678"

        with DecisionGraph(db_path) as dg:
            returned_id = dg.start_trace(
                workflow="test",
                title="Explicit ID Test",
                primary_entity=entity,
                source=source,
                actor=actor,
                trace_id=explicit_id,
            )

            assert returned_id == explicit_id

    def test_start_with_context(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """Start trace with context data."""
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="renewal",
                title="Context Test",
                primary_entity=entity,
                source=source,
                actor=actor,
                context={"region": "US", "channel": "web"},
            )

            events = dg.get_trace_events(trace_id)
            assert len(events) == 1
            assert events[0].payload.get("context", {}).get("region") == "US"

    def test_finish_with_summary(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """Finish trace with summary."""
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="test",
                title="Summary Test",
                primary_entity=entity,
                source=source,
                actor=actor,
            )

            dg.finish_trace(
                trace_id=trace_id,
                outcome="success",
                source=source,
                actor=actor,
                summary="Completed successfully with no issues",
            )

            events = dg.get_trace_events(trace_id)
            finish_event = [e for e in events if "outcome" in e.payload][0]
            assert finish_event.payload["summary"] == "Completed successfully with no issues"

    def test_typed_helper_methods_append_expected_events(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """Structured helper APIs should append the expected event types and payloads."""
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="typed",
                title="Typed helper test",
                primary_entity=entity,
                source=source,
                actor=actor,
            )

            fact = Fact(key="segment", value=Value(type="string", value="strategic"))
            policy = PolicyRef(policy_id="discount-cap", policy_version="1.0")

            dg.observe_input(
                trace_id=trace_id,
                input_id="input-1",
                input_source=SourceObjectRef(
                    system="crm",
                    object_type="ticket",
                    object_id="t-1",
                ),
                facts=[fact],
                source=source,
                actor=actor,
            )
            dg.observe_entity(
                trace_id=trace_id,
                entity=EntityRef(entity_type="Account", entity_id="A-1", system="crm"),
                role="related",
                facts=[fact],
                source=source,
                actor=actor,
            )
            dg.evaluate_policy(
                trace_id=trace_id,
                policy=policy,
                inputs=["input-1"],
                decision="require_exception",
                source=source,
                actor=actor,
            )
            dg.request_exception(
                trace_id=trace_id,
                exception_id="exc-1",
                policy=policy,
                reason="Strategic account",
                source=source,
                actor=actor,
            )
            dg.record_approval(
                trace_id=trace_id,
                approval_id="appr-1",
                subject=ApprovalSubject(subject_type="exception", subject_id="exc-1"),
                approver=ActorRef(actor_type="person", actor_id="approver-1"),
                decision="approved",
                source=source,
                actor=actor,
                reason="Approved by policy owner",
            )
            dg.cite_precedent(
                trace_id=trace_id,
                cited_trace_id="trace-old-1",
                reason="Matched prior strategic exception",
                source=source,
                actor=actor,
                similarity_score="0.91",
            )
            dg.propose_action(
                trace_id=trace_id,
                action_id="act-1",
                action_type="update",
                target_entity=entity,
                target_system="crm",
                changes=[
                    Change(
                        path="discount",
                        old_value=Value(type="decimal", value="0.05"),
                        new_value=Value(type="decimal", value="0.07"),
                    )
                ],
                source=source,
                actor=actor,
            )
            dg.commit_action(
                trace_id=trace_id,
                action_id="act-1",
                status="success",
                source=source,
                actor=actor,
                external_reference="crm-change-1",
            )

            events = dg.get_trace_events(trace_id)
            event_types = [event.event_type for event in events]
            assert event_types == [
                "TraceStarted",
                "InputObserved",
                "EntityObserved",
                "PolicyEvaluated",
                "ExceptionRequested",
                "ApprovalRecorded",
                "PrecedentCited",
                "ActionProposed",
                "ActionCommitted",
            ]
            assert events[1].payload["source"]["system"] == "crm"
            assert events[3].payload["policy"]["policy_id"] == "discount-cap"
            assert events[8].payload["external_reference"] == "crm-change-1"


class TestOutcomeTypes:
    """Tests for different outcome types."""

    @pytest.mark.parametrize("outcome", ["success", "failure", "abandoned"])
    def test_valid_outcomes(
        self,
        db_path: str,
        source: SourceRef,
        actor: ActorRef,
        entity: EntityRef,
        outcome: str,
    ) -> None:
        """All valid outcome types work correctly."""
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="test",
                title=f"Test {outcome}",
                primary_entity=entity,
                source=source,
                actor=actor,
            )

            dg.finish_trace(
                trace_id=trace_id,
                outcome=outcome,  # type: ignore[arg-type]
                source=source,
                actor=actor,
            )

            events = dg.get_trace_events(trace_id)
            finish_event = [e for e in events if "outcome" in e.payload][0]
            assert finish_event.payload["outcome"] == outcome


class TestIdempotency:
    """Tests for idempotency behavior."""

    def test_storage_idempotency_preserves_event(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """Idempotent storage append returns existing event."""
        # Note: API-level idempotency is more complex since projector
        # tracks state. This tests that storage layer handles it correctly.
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="test",
                title="Idempotent Test",
                primary_entity=entity,
                source=source,
                actor=actor,
            )

            # Only one event should exist
            events = dg.get_trace_events(trace_id)
            assert len(events) == 1
            assert events[0].trace_seq == 0

    def test_start_trace_retry_is_idempotent(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """Retrying start_trace with same trace_id returns same stored event."""
        with DecisionGraph(db_path) as dg:
            trace_id = "trace-idem-start"
            first = dg.start_trace(
                workflow="test",
                title="Idempotent start",
                primary_entity=entity,
                source=source,
                actor=actor,
                trace_id=trace_id,
            )
            second = dg.start_trace(
                workflow="test",
                title="Idempotent start",
                primary_entity=entity,
                source=source,
                actor=actor,
                trace_id=trace_id,
            )

            assert first == second
            events = dg.get_trace_events(trace_id)
            assert len(events) == 1
            assert events[0].trace_seq == 0

    def test_finish_trace_retry_is_idempotent(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """Retrying finish_trace with same outcome returns existing event."""
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="test",
                title="Idempotent finish",
                primary_entity=entity,
                source=source,
                actor=actor,
            )
            first = dg.finish_trace(
                trace_id=trace_id,
                outcome="success",
                source=source,
                actor=actor,
                summary="done",
            )
            second = dg.finish_trace(
                trace_id=trace_id,
                outcome="success",
                source=source,
                actor=actor,
                summary="done",
            )

            assert first.log_seq == second.log_seq
            events = dg.get_trace_events(trace_id)
            assert len(events) == 2


class TestErrorHandling:
    """Tests for error handling scenarios."""

    def test_finish_already_finished_trace(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """Finishing already finished trace raises error."""
        from decisiongraph.errors import DG_ERR_IDEMPOTENCY_CONFLICT

        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="test",
                title="Double Finish Test",
                primary_entity=entity,
                source=source,
                actor=actor,
            )

            dg.finish_trace(
                trace_id=trace_id,
                outcome="success",
                source=source,
                actor=actor,
            )

            with pytest.raises(DecisionGraphError) as exc_info:
                dg.finish_trace(
                    trace_id=trace_id,
                    outcome="failure",  # Different outcome = different payload
                    source=source,
                    actor=actor,
                )

            # Raises idempotency conflict because same key with different payload
            assert exc_info.value.code == DG_ERR_IDEMPOTENCY_CONFLICT

    def test_pii_in_payload_rejected(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """PII in context is rejected."""
        with DecisionGraph(db_path) as dg:
            with pytest.raises(DecisionGraphError) as exc_info:
                dg.start_trace(
                    workflow="test",
                    title="PII Test",
                    primary_entity=entity,
                    source=source,
                    actor=actor,
                    context={"token": "Bearer secret123"},  # PII!
                )

            assert exc_info.value.code == DG_ERR_PII_POLICY_VIOLATION


class TestContextManager:
    """Tests for context manager behavior."""

    def test_context_manager_closes_on_exit(self, db_path: str) -> None:
        """Context manager closes database on exit."""
        dg = DecisionGraph(db_path)
        assert dg._store is not None

        with dg:
            pass

        # After exit, store should be closed (connection closed)
        # We can verify by trying to access it
        import sqlite3

        with pytest.raises(sqlite3.ProgrammingError):
            dg._store.connection.execute("SELECT 1")

    def test_context_manager_closes_on_exception(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """Context manager closes database even on exception."""
        class TestException(Exception):
            pass

        dg = DecisionGraph(db_path)

        with pytest.raises(TestException), dg:
            dg.start_trace(
                workflow="test",
                title="Exception Test",
                primary_entity=entity,
                source=source,
                actor=actor,
            )
            raise TestException("Intentional error")

        # Store should still be closed
        import sqlite3

        with pytest.raises(sqlite3.ProgrammingError):
            dg._store.connection.execute("SELECT 1")


class TestPersistence:
    """Tests for data persistence across sessions."""

    def test_trace_persists_across_sessions(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """Trace data persists across sessions."""
        # First session - create trace
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="persistence",
                title="Persistence Test",
                primary_entity=entity,
                source=source,
                actor=actor,
            )
            dg.finish_trace(
                trace_id=trace_id,
                outcome="success",
                source=source,
                actor=actor,
            )

        # Second session - verify trace
        with DecisionGraph(db_path) as dg:
            events = dg.get_trace_events(trace_id)
            assert len(events) == 2
            assert dg.is_trace_finished(trace_id)


class TestQueryIntegration:
    """Tests for query integration through API."""

    def test_get_trace_events(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """get_trace_events returns correct events."""
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="query",
                title="Query Test",
                primary_entity=entity,
                source=source,
                actor=actor,
            )
            dg.finish_trace(
                trace_id=trace_id,
                outcome="success",
                source=source,
                actor=actor,
            )

            events = dg.get_trace_events(trace_id)
            assert len(events) == 2
            assert events[0].trace_seq == 0
            assert events[1].trace_seq == 1

    def test_get_context_subgraph(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """get_context_subgraph returns graph data."""
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="graph",
                title="Graph Test",
                primary_entity=entity,
                source=source,
                actor=actor,
            )

            subgraph = dg.get_context_subgraph(
                node_type="trace",
                node_id=trace_id,
                max_depth=1,
            )

            assert subgraph.center.node_type == "trace"
            assert subgraph.center.node_id == trace_id

    def test_find_precedents_empty(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """find_precedents returns empty list when no matches."""
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="precedent",
                title="Precedent Test",
                primary_entity=entity,
                source=source,
                actor=actor,
            )
            dg.finish_trace(
                trace_id=trace_id,
                outcome="success",
                source=source,
                actor=actor,
            )

            # No precedent citations exist
            hits = dg.find_precedents(policy_id="nonexistent")
            assert hits == []


class TestProjectionMaintenance:
    """Tests for projection sync/replay behavior."""

    def test_sync_projections_processes_all_pending_events_in_batches(
        self,
        db_path: str,
        source: SourceRef,
        actor: ActorRef,
        entity: EntityRef,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="sync-batches",
                title="sync batches",
                primary_entity=entity,
                source=source,
                actor=actor,
            )

            with SQLiteEventStore(db_path) as external_store:
                for idx in range(1, 6):
                    env = create_test_envelope(
                        trace_id=trace_id,
                        trace_seq=idx,
                        event_type=EVENT_TYPE_ENTITY_OBSERVED,
                        payload={
                            "entity": {
                                "entity_type": "Contract",
                                "entity_id": f"C-{idx}",
                            },
                            "role": "related",
                            "facts": [],
                        },
                        producer_id=source.producer_id,
                    )
                    external_store.append_event(env)

            original_list_events = dg._store.list_events
            requested_limits: list[int | None] = []

            def tracked_list_events(
                since_log_seq: int | None = None,
                until_log_seq: int | None = None,
                event_type: str | None = None,
                trace_id: str | None = None,
                limit: int | None = None,
            ):
                requested_limits.append(limit)
                return original_list_events(
                    since_log_seq=since_log_seq,
                    until_log_seq=until_log_seq,
                    event_type=event_type,
                    trace_id=trace_id,
                    limit=limit,
                )

            monkeypatch.setattr(dg._store, "list_events", tracked_list_events)

            processed = dg.sync_projections(batch_size=2)

            assert processed == 5
            assert requested_limits.count(2) >= 3
            assert dg._projector.get_cursor() == dg._store.get_last_log_seq()

    def test_replay_projections_reads_event_log_in_batches(
        self,
        db_path: str,
        source: SourceRef,
        actor: ActorRef,
        entity: EntityRef,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="replay-batches",
                title="replay batches",
                primary_entity=entity,
                source=source,
                actor=actor,
            )
            for _ in range(3):
                dg.append_event(
                    trace_id=trace_id,
                    event_type=EVENT_TYPE_ENTITY_OBSERVED,
                    payload={
                        "entity": {
                            "entity_type": "Contract",
                            "entity_id": f"C-{dg._store.get_next_trace_seq(trace_id)}",
                        },
                        "role": "related",
                        "facts": [],
                    },
                    source=source,
                    actor=actor,
                )

            original_list_events = dg._store.list_events
            requested_limits: list[int | None] = []

            def tracked_list_events(
                since_log_seq: int | None = None,
                until_log_seq: int | None = None,
                event_type: str | None = None,
                trace_id: str | None = None,
                limit: int | None = None,
            ):
                requested_limits.append(limit)
                return original_list_events(
                    since_log_seq=since_log_seq,
                    until_log_seq=until_log_seq,
                    event_type=event_type,
                    trace_id=trace_id,
                    limit=limit,
                )

            monkeypatch.setattr(dg._store, "list_events", tracked_list_events)

            dg.replay_projections(batch_size=2)

            assert requested_limits.count(2) >= 2
            assert dg._projector.get_cursor() == dg._store.get_last_log_seq()

    @pytest.mark.parametrize(
        "method_name",
        ["sync_projections", "replay_projections"],
    )
    def test_projection_maintenance_rejects_non_positive_batch_size(
        self,
        db_path: str,
        method_name: str,
    ) -> None:
        with DecisionGraph(db_path) as dg:
            method = getattr(dg, method_name)
            with pytest.raises(DecisionGraphError) as exc_info:
                method(batch_size=0)

            assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT

    def test_replay_projections_handles_larger_logs_in_batches(
        self,
        db_path: str,
        source: SourceRef,
        actor: ActorRef,
        entity: EntityRef,
    ) -> None:
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="large-replay",
                title="large replay",
                primary_entity=entity,
                source=source,
                actor=actor,
            )
            for idx in range(1, 251):
                dg.append_event(
                    trace_id=trace_id,
                    event_type=EVENT_TYPE_ENTITY_OBSERVED,
                    payload={
                        "entity": {
                            "entity_type": "Contract",
                            "entity_id": f"C-{idx}",
                        },
                        "role": "related",
                        "facts": [],
                    },
                    source=source,
                    actor=actor,
                )

            dg.finish_trace(
                trace_id=trace_id,
                outcome="success",
                source=source,
                actor=actor,
            )

            dg.replay_projections(batch_size=32)

            assert dg._projector.get_cursor() == dg._store.get_last_log_seq()
            assert len(dg.get_trace_events(trace_id)) == 252

    def test_get_projection_health_reports_cursor_lag_and_digests(
        self,
        db_path: str,
        source: SourceRef,
        actor: ActorRef,
        entity: EntityRef,
    ) -> None:
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="health",
                title="health check",
                primary_entity=entity,
                source=source,
                actor=actor,
            )

            with SQLiteEventStore(db_path) as external_store:
                env = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=1,
                    event_type=EVENT_TYPE_ENTITY_OBSERVED,
                    payload={
                        "entity": {
                            "entity_type": "Contract",
                            "entity_id": "C-health",
                        },
                        "role": "related",
                        "facts": [],
                    },
                    producer_id=source.producer_id,
                )
                external_store.append_event(env)

            stale = dg.get_projection_health()
            assert stale.is_stale is True
            assert stale.pending_events == 1
            assert stale.event_count == 2
            assert stale.digests is None

            dg.sync_projections()
            healthy = dg.get_projection_health(include_digests=True)
            assert healthy.is_stale is False
            assert healthy.pending_events == 0
            assert healthy.digests is not None
            assert set(healthy.digests) == {
                "context_graph",
                "trace_summary",
                "precedent_index",
                "full_projection",
            }


class TestIsTraceFinished:
    """Tests for is_trace_finished method."""

    def test_unstarted_trace(self, db_path: str) -> None:
        """Unstarted trace is not finished."""
        with DecisionGraph(db_path) as dg:
            assert dg.is_trace_finished("nonexistent") is False

    def test_started_trace(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """Started but not finished trace is not finished."""
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="test",
                title="Test",
                primary_entity=entity,
                source=source,
                actor=actor,
            )
            assert dg.is_trace_finished(trace_id) is False

    def test_finished_trace(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """Finished trace is finished."""
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="test",
                title="Test",
                primary_entity=entity,
                source=source,
                actor=actor,
            )
            dg.finish_trace(
                trace_id=trace_id,
                outcome="success",
                source=source,
                actor=actor,
            )
            assert dg.is_trace_finished(trace_id) is True


class TestEventSequence:
    """Tests for event sequence behavior."""

    def test_events_have_correct_trace_seq(
        self, db_path: str, source: SourceRef, actor: ActorRef, entity: EntityRef
    ) -> None:
        """Events have incrementing trace_seq values."""
        with DecisionGraph(db_path) as dg:
            trace_id = dg.start_trace(
                workflow="seq",
                title="Sequence Test",
                primary_entity=entity,
                source=source,
                actor=actor,
            )
            dg.finish_trace(
                trace_id=trace_id,
                outcome="success",
                source=source,
                actor=actor,
            )

            events = dg.get_trace_events(trace_id)
            for i, event in enumerate(events):
                assert event.trace_seq == i

    def test_events_have_incrementing_log_seq(
        self, db_path: str, source: SourceRef, actor: ActorRef
    ) -> None:
        """Events have incrementing log_seq values."""
        with DecisionGraph(db_path) as dg:
            # Create multiple traces with different entities
            for i in range(3):
                entity_i = EntityRef(entity_type="Contract", entity_id=f"C-{i}", system="test")
                trace_id = dg.start_trace(
                    workflow="seq",
                    title=f"Trace {i}",
                    primary_entity=entity_i,
                    source=source,
                    actor=actor,
                )
                dg.finish_trace(
                    trace_id=trace_id,
                    outcome="success",
                    source=source,
                    actor=actor,
                )

            # All events should have unique incrementing log_seq
            all_events = dg._store.list_events()
            log_seqs = [e.log_seq for e in all_events]
            assert log_seqs == sorted(log_seqs)
            assert len(log_seqs) == len(set(log_seqs))  # All unique
