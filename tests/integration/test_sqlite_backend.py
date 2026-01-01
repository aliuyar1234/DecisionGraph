"""Integration tests for SQLite storage backend - TC-P2-001 through TC-P2-010."""

import tempfile
from pathlib import Path

import pytest

from decisiongraph.domain.events import (
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
)
from decisiongraph.errors import (
    DG_ERR_CONFLICT,
    DG_ERR_EVENT_SEQUENCE_INVALID,
    DG_ERR_IDEMPOTENCY_CONFLICT,
    DG_ERR_PII_POLICY_VIOLATION,
    DecisionGraphError,
)
from decisiongraph.ids import generate_trace_id
from decisiongraph.serialization import compute_payload_hash
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.testing import create_test_envelope


class TestMigration:
    """Tests for database migration."""

    def test_sqlite_migrate_fresh_db(self) -> None:
        """TC-P2-001: Migrations apply to fresh database."""
        with SQLiteEventStore(":memory:") as store:
            # Check that the event log table exists
            cursor = store._conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='dg_event_log'"
            )
            assert cursor.fetchone() is not None

            # Check that migrations table exists
            cursor = store._conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='schema_migrations'"
            )
            assert cursor.fetchone() is not None

    def test_pending_migrations_applied(self) -> None:
        """Pending migrations are applied on existing database."""
        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
            db_path = f.name

        try:
            # First open - creates and migrates
            with SQLiteEventStore(db_path) as store:
                version1 = store._conn.execute(
                    "SELECT MAX(version) FROM schema_migrations"
                ).fetchone()[0]
                assert version1 >= 1

            # Second open - no new migrations needed
            with SQLiteEventStore(db_path) as store:
                version2 = store._conn.execute(
                    "SELECT MAX(version) FROM schema_migrations"
                ).fetchone()[0]
                assert version1 == version2
        finally:
            Path(db_path).unlink(missing_ok=True)

    def test_no_migrations_when_current(self) -> None:
        """No migrations run when schema is current."""
        with SQLiteEventStore(":memory:") as store:
            # Get initial count
            cursor = store._conn.execute("SELECT COUNT(*) FROM schema_migrations")
            initial_count = cursor.fetchone()[0]

            # Re-migrate - should do nothing
            store._migrate()

            cursor = store._conn.execute("SELECT COUNT(*) FROM schema_migrations")
            final_count = cursor.fetchone()[0]
            assert initial_count == final_count


class TestPersistence:
    """Tests for event persistence."""

    def test_sqlite_append_persists(self) -> None:
        """TC-P2-002: Events survive connection close."""
        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
            db_path = f.name

        try:
            trace_id = generate_trace_id()

            # First connection - append event
            with SQLiteEventStore(db_path) as store:
                env = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=0,
                    event_type=EVENT_TYPE_TRACE_STARTED,
                    payload={"workflow": "test", "title": "Persistence test"},
                )
                stored = store.append_event(env)
                log_seq = stored.log_seq

            # Second connection - retrieve event
            with SQLiteEventStore(db_path) as store:
                events = store.get_trace_events(trace_id)
                assert len(events) == 1
                assert events[0].log_seq == log_seq
                assert events[0].payload["title"] == "Persistence test"
        finally:
            Path(db_path).unlink(missing_ok=True)

    def test_sqlite_restart_preserves_seq(self) -> None:
        """TC-P2-009: log_seq continues after restart."""
        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
            db_path = f.name

        try:
            # First connection - add events
            with SQLiteEventStore(db_path) as store:
                for i in range(5):
                    trace_id = generate_trace_id()
                    env = create_test_envelope(
                        trace_id=trace_id,
                        trace_seq=0,
                        event_type=EVENT_TYPE_TRACE_STARTED,
                        payload={"workflow": "test", "title": f"Event {i}"},
                    )
                    store.append_event(env)

                last_seq = store.get_last_log_seq()
                assert last_seq == 5

            # Second connection - continue sequence
            with SQLiteEventStore(db_path) as store:
                trace_id = generate_trace_id()
                env = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=0,
                    event_type=EVENT_TYPE_TRACE_STARTED,
                    payload={"workflow": "test", "title": "Event after restart"},
                )
                stored = store.append_event(env)
                assert stored.log_seq == 6  # Continues from 5
        finally:
            Path(db_path).unlink(missing_ok=True)


class TestIdempotency:
    """Tests for idempotency behavior."""

    def test_sqlite_idempotency_unique(self) -> None:
        """TC-P2-003: Idempotency constraint works."""
        with SQLiteEventStore(":memory:") as store:
            trace_id = generate_trace_id()
            payload = {"workflow": "test", "title": "Idempotency test"}

            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload=payload,
                idempotency_key="idem-key-1",
            )

            # First append
            stored1 = store.append_event(env)

            # Second append with same key and payload - idempotent success
            stored2 = store.append_event(env)
            assert stored1.log_seq == stored2.log_seq

    def test_idempotency_conflict_different_payload(self) -> None:
        """Same idempotency key with different payload raises error."""
        with SQLiteEventStore(":memory:") as store:
            trace_id = generate_trace_id()

            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Original"},
                idempotency_key="conflict-key",
            )
            store.append_event(env1)

            env2 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Modified"},
                idempotency_key="conflict-key",
            )

            with pytest.raises(DecisionGraphError) as exc_info:
                store.append_event(env2)

            assert exc_info.value.code == DG_ERR_IDEMPOTENCY_CONFLICT


class TestTraceSequence:
    """Tests for trace_seq enforcement."""

    def test_sqlite_trace_seq_unique(self) -> None:
        """TC-P2-004: trace_seq uniqueness enforced."""
        with SQLiteEventStore(":memory:") as store:
            trace_id = generate_trace_id()

            # First event
            env0 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
            )
            store.append_event(env0)

            # Try to skip seq=1
            env2 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=2,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={"entity": {"entity_type": "Test", "entity_id": "1"}},
            )

            with pytest.raises(DecisionGraphError) as exc_info:
                store.append_event(env2)

            assert exc_info.value.code == DG_ERR_EVENT_SEQUENCE_INVALID

    def test_sqlite_trace_events_order(self) -> None:
        """TC-P2-005: Events ordered by trace_seq."""
        with SQLiteEventStore(":memory:") as store:
            trace_id = generate_trace_id()

            for i in range(5):
                event_type = (
                    EVENT_TYPE_TRACE_STARTED if i == 0 else EVENT_TYPE_ENTITY_OBSERVED
                )
                payload = (
                    {"workflow": "test", "title": "Test"}
                    if i == 0
                    else {"entity": {"entity_type": "Test", "entity_id": str(i)}}
                )
                env = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=i,
                    event_type=event_type,
                    payload=payload,
                )
                store.append_event(env)

            events = store.get_trace_events(trace_id)
            assert [e.trace_seq for e in events] == [0, 1, 2, 3, 4]

    def test_sqlite_list_events_order(self) -> None:
        """TC-P2-006: Events ordered by log_seq."""
        with SQLiteEventStore(":memory:") as store:
            # Create multiple traces
            for _ in range(3):
                trace_id = generate_trace_id()
                env = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=0,
                    event_type=EVENT_TYPE_TRACE_STARTED,
                    payload={"workflow": "test", "title": "Test"},
                )
                store.append_event(env)

            events = store.list_events()
            log_seqs = [e.log_seq for e in events]
            assert log_seqs == sorted(log_seqs)
            assert log_seqs == [1, 2, 3]


class TestTraceFinish:
    """Tests for TraceFinished behavior."""

    def test_sqlite_finish_locks(self) -> None:
        """TC-P2-008: TraceFinished prevents appends."""
        with SQLiteEventStore(":memory:") as store:
            trace_id = generate_trace_id()

            # Start trace
            env0 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
            )
            store.append_event(env0)

            # Finish trace
            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_TRACE_FINISHED,
                payload={"outcome": "success"},
            )
            store.append_event(env1)

            # Try to add more events
            env2 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=2,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={"entity": {"entity_type": "Test", "entity_id": "1"}},
            )

            with pytest.raises(DecisionGraphError) as exc_info:
                store.append_event(env2)

            assert exc_info.value.code == DG_ERR_CONFLICT


class TestPayloadHash:
    """Tests for payload hash verification."""

    def test_sqlite_payload_hash_verified(self) -> None:
        """TC-P2-007: Hash matches on read."""
        with SQLiteEventStore(":memory:") as store:
            trace_id = generate_trace_id()
            payload = {"workflow": "test", "title": "Hash test"}

            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload=payload,
            )
            stored = store.append_event(env)

            # Verify hash matches
            expected_hash = compute_payload_hash(payload)
            assert stored.payload_hash == expected_hash

            # Retrieve and verify
            events = store.get_trace_events(trace_id)
            assert events[0].payload_hash == expected_hash

    def test_sqlite_reject_invalid_payload(self) -> None:
        """TC-P2-010: Invalid payloads rejected."""
        with SQLiteEventStore(":memory:") as store:
            trace_id = generate_trace_id()

            # PII in payload should be rejected
            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test", "token": "Bearer secret"},
            )

            with pytest.raises(DecisionGraphError) as exc_info:
                store.append_event(env)

            assert exc_info.value.code == DG_ERR_PII_POLICY_VIOLATION


class TestQueryFilters:
    """Tests for query filtering."""

    def test_get_trace_events_since(self) -> None:
        """Filter by since_trace_seq."""
        with SQLiteEventStore(":memory:") as store:
            trace_id = generate_trace_id()

            for i in range(3):
                event_type = (
                    EVENT_TYPE_TRACE_STARTED if i == 0 else EVENT_TYPE_ENTITY_OBSERVED
                )
                payload = (
                    {"workflow": "test", "title": "Test"}
                    if i == 0
                    else {"entity": {"entity_type": "Test", "entity_id": str(i)}}
                )
                env = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=i,
                    event_type=event_type,
                    payload=payload,
                )
                store.append_event(env)

            events = store.get_trace_events(trace_id, since_trace_seq=0)
            assert len(events) == 2
            assert events[0].trace_seq == 1
            assert events[1].trace_seq == 2

    def test_get_trace_events_limit(self) -> None:
        """Limit number of events."""
        with SQLiteEventStore(":memory:") as store:
            trace_id = generate_trace_id()

            for i in range(5):
                event_type = (
                    EVENT_TYPE_TRACE_STARTED if i == 0 else EVENT_TYPE_ENTITY_OBSERVED
                )
                payload = (
                    {"workflow": "test", "title": "Test"}
                    if i == 0
                    else {"entity": {"entity_type": "Test", "entity_id": str(i)}}
                )
                env = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=i,
                    event_type=event_type,
                    payload=payload,
                )
                store.append_event(env)

            events = store.get_trace_events(trace_id, limit=2)
            assert len(events) == 2

    def test_list_events_filter_by_type(self) -> None:
        """Filter by event type."""
        with SQLiteEventStore(":memory:") as store:
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
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={"entity": {"entity_type": "Test", "entity_id": "1"}},
            )

            store.append_event(env0)
            store.append_event(env1)

            events = store.list_events(event_type=EVENT_TYPE_TRACE_STARTED)
            assert len(events) == 1
            assert events[0].event_type == EVENT_TYPE_TRACE_STARTED


class TestTransactions:
    """Tests for transaction behavior."""

    def test_transaction_rollback_on_error(self) -> None:
        """Failed insert doesn't leave partial state."""
        with SQLiteEventStore(":memory:") as store:
            trace_id = generate_trace_id()

            # Start trace
            env0 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
            )
            store.append_event(env0)

            # Try invalid insert (wrong trace_seq)
            env_invalid = create_test_envelope(
                trace_id=trace_id,
                trace_seq=5,  # Wrong!
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={"entity": {"entity_type": "Test", "entity_id": "1"}},
            )

            with pytest.raises(DecisionGraphError):
                store.append_event(env_invalid)

            # Verify only original event exists
            events = store.get_trace_events(trace_id)
            assert len(events) == 1


class TestClear:
    """Tests for clear method."""

    def test_clear_removes_all(self) -> None:
        """Clear removes all events."""
        with SQLiteEventStore(":memory:") as store:
            trace_id = generate_trace_id()

            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
            )
            store.append_event(env)
            assert store.get_last_log_seq() == 1

            store.clear()

            assert store.get_last_log_seq() == 0
            assert store.list_events() == []
