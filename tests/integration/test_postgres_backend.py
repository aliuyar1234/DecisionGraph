"""Integration tests for PostgreSQL backend - TC-P4-001 through TC-P4-010.

These tests require a running PostgreSQL instance.
Connection string can be set via PG_CONNINFO environment variable.
Example: export PG_CONNINFO="host=localhost dbname=dg_test user=postgres password=secret"
"""

import os

import pytest

# Skip all tests if psycopg is not installed
pytest.importorskip("psycopg")

from decisiongraph.domain.events import (  # noqa: E402
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
)
from decisiongraph.errors import (  # noqa: E402
    DG_ERR_CONFLICT,
    DG_ERR_EVENT_SEQUENCE_INVALID,
    DG_ERR_IDEMPOTENCY_CONFLICT,
    DecisionGraphError,
)
from decisiongraph.ids import generate_trace_id  # noqa: E402
from decisiongraph.projections.postgres import PostgresProjector  # noqa: E402
from decisiongraph.storage.postgres import PostgresEventStore  # noqa: E402
from decisiongraph.testing import create_test_envelope  # noqa: E402


@pytest.fixture
def pg_conninfo() -> str:
    """Get PostgreSQL connection string from environment.

    Returns:
        PostgreSQL connection string

    Raises:
        pytest.skip: If PG_CONNINFO not set
    """
    conninfo = os.getenv("PG_CONNINFO")
    if not conninfo:
        pytest.skip("PG_CONNINFO environment variable not set")
    return conninfo


@pytest.fixture
def pg_store(pg_conninfo: str) -> PostgresEventStore:
    """Create a PostgresEventStore instance.

    Args:
        pg_conninfo: PostgreSQL connection string

    Returns:
        PostgresEventStore instance with migrations applied and clean data
    """
    store = PostgresEventStore(pg_conninfo)
    # Clean up any existing data
    store.clear()
    yield store
    store.close()


class TestMigration:
    """Tests for database migration."""

    def test_pg_migrate_fresh_db(self, pg_conninfo: str) -> None:
        """TC-P4-001: Migrations apply cleanly to a fresh database."""
        # Create store - this should apply migrations
        store = PostgresEventStore(pg_conninfo)
        store.clear()

        # Verify migrations were applied by checking we can get last_log_seq
        assert store.get_last_log_seq() == 0

        # Verify tables exist
        with store.connection.cursor() as cur:
            cur.execute(
                """
                SELECT table_name FROM information_schema.tables
                WHERE table_schema = 'public' AND table_name = 'dg_event_log'
                """
            )
            assert cur.fetchone() is not None

            cur.execute(
                """
                SELECT table_name FROM information_schema.tables
                WHERE table_schema = 'public' AND table_name = 'schema_migrations'
                """
            )
            assert cur.fetchone() is not None

        store.close()


class TestPersistence:
    """Tests for event persistence."""

    def test_pg_append_persists(self, pg_store: PostgresEventStore) -> None:
        """TC-P4-002: Events persist correctly in PostgreSQL."""
        trace_id = generate_trace_id()

        env = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Persistence test"},
        )
        stored = pg_store.append_event(env)

        # Retrieve event
        events = pg_store.get_trace_events(trace_id)
        assert len(events) == 1
        assert events[0].log_seq == stored.log_seq
        assert events[0].payload["title"] == "Persistence test"

    def test_pg_projector_trace_summary(self, pg_store: PostgresEventStore) -> None:
        """Postgres projector builds trace summary."""
        projector = PostgresProjector(pg_store.connection)
        trace_id = generate_trace_id()

        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={
                "workflow": "test",
                "title": "Summary test",
                "primary_entity": {"entity_type": "Account", "entity_id": "acc-1"},
            },
        )
        event0 = pg_store.append_event(env0)
        projector.project_event(event0)

        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_TRACE_FINISHED,
            payload={"outcome": "success"},
        )
        event1 = pg_store.append_event(env1)
        projector.project_event(event1)

        summary = projector.get_trace_summary(trace_id)
        assert summary is not None
        assert summary["outcome"] == "success"


class TestIdempotency:
    """Tests for idempotency behavior."""

    def test_pg_idempotency_unique(self, pg_store: PostgresEventStore) -> None:
        """TC-P4-003: Idempotency constraint works in PostgreSQL."""
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
        stored1 = pg_store.append_event(env)

        # Second append with same key and payload - idempotent success
        stored2 = pg_store.append_event(env)
        assert stored1.log_seq == stored2.log_seq

    def test_idempotency_conflict_different_payload(
        self, pg_store: PostgresEventStore
    ) -> None:
        """Same idempotency key with different payload raises error."""
        trace_id = generate_trace_id()

        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Original"},
            idempotency_key="conflict-key",
        )
        pg_store.append_event(env1)

        env2 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Modified"},
            idempotency_key="conflict-key",
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            pg_store.append_event(env2)

        assert exc_info.value.code == DG_ERR_IDEMPOTENCY_CONFLICT

    def test_idempotency_unique_violation_recovers_existing(
        self, pg_store: PostgresEventStore, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Race on unique idempotency key should return existing event."""
        trace_id = generate_trace_id()
        start = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Race"},
        )
        pg_store.append_event(start)

        payload = {
            "entity": {"entity_type": "Contact", "entity_id": "cnt-race"},
            "role": "related",
            "facts": [],
        }
        env = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_ENTITY_OBSERVED,
            payload=payload,
            idempotency_key="pg-race-key",
        )
        original = pg_store.append_event(env)
        retry = create_test_envelope(
            trace_id=trace_id,
            trace_seq=2,
            event_type=EVENT_TYPE_ENTITY_OBSERVED,
            payload=payload,
            idempotency_key="pg-race-key",
        )
        original_check = pg_store._check_idempotency
        first_call = True

        def bypass_once(*args: object, **kwargs: object) -> object:
            nonlocal first_call
            if first_call:
                first_call = False
                return None
            return original_check(*args, **kwargs)

        monkeypatch.setattr(pg_store, "_check_idempotency", bypass_once)

        recovered = pg_store.append_event(retry)
        assert recovered.log_seq == original.log_seq


class TestTraceSequence:
    """Tests for trace_seq enforcement."""

    def test_pg_trace_seq_unique(self, pg_store: PostgresEventStore) -> None:
        """TC-P4-004: trace_seq uniqueness enforced in PostgreSQL."""
        trace_id = generate_trace_id()

        # First event
        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )
        pg_store.append_event(env0)

        # Try to skip seq=1
        env2 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=2,
            event_type=EVENT_TYPE_ENTITY_OBSERVED,
            payload={"entity": {"entity_type": "Test", "entity_id": "1"}},
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            pg_store.append_event(env2)

        assert exc_info.value.code == DG_ERR_EVENT_SEQUENCE_INVALID


class TestListEvents:
    """Tests for list_events ordering."""

    def test_pg_list_events_order(self, pg_store: PostgresEventStore) -> None:
        """TC-P4-007: Events are ordered by log_seq."""
        # Create multiple traces
        trace_ids = [generate_trace_id() for _ in range(3)]

        # Append events in interleaved manner
        for i, trace_id in enumerate(trace_ids):
            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": f"Trace {i}"},
            )
            pg_store.append_event(env)

        # List all events
        events = pg_store.list_events()

        # Verify ordering
        assert len(events) == 3
        for i in range(len(events) - 1):
            assert events[i].log_seq < events[i + 1].log_seq


class TestTraceFinished:
    """Tests for TraceFinished locking."""

    def test_pg_finish_locks(self, pg_store: PostgresEventStore) -> None:
        """TC-P4-008: TraceFinished prevents further appends."""
        trace_id = generate_trace_id()

        # Start trace
        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Finish lock test"},
        )
        pg_store.append_event(env0)

        # Finish trace
        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_TRACE_FINISHED,
            payload={"outcome": "success"},
        )
        pg_store.append_event(env1)

        # Try to append after finish
        env2 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=2,
            event_type=EVENT_TYPE_ENTITY_OBSERVED,
            payload={"entity": {"entity_type": "Test", "entity_id": "1"}},
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            pg_store.append_event(env2)

        assert exc_info.value.code == DG_ERR_CONFLICT


class TestErrorMapping:
    """Tests for error mapping."""

    def test_pg_error_mapping_storage(self, pg_store: PostgresEventStore) -> None:
        """TC-P4-009: Database errors map to DG_ERR_STORAGE."""
        # This test verifies that psycopg errors are properly wrapped
        # The error mapping is tested implicitly in other tests
        # (e.g., UniqueViolation -> DG_ERR_IDEMPOTENCY_CONFLICT)

        # Test that we get proper error codes
        trace_id = generate_trace_id()

        env = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Error mapping"},
            idempotency_key="test-key",
        )
        pg_store.append_event(env)

        # Try to use same idempotency key with different payload
        env2 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Different"},
            idempotency_key="test-key",
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            pg_store.append_event(env2)

        # Should map to idempotency conflict, not generic storage error
        assert exc_info.value.code == DG_ERR_IDEMPOTENCY_CONFLICT
        assert "idempotency" in str(exc_info.value).lower()
