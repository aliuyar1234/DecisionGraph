"""Parity tests between SQLite and PostgreSQL backends.

These tests verify that SQLite and PostgreSQL produce identical results
for the same operations, including projection digests.
"""

import os
from collections.abc import Iterator

import pytest

# Skip all tests if psycopg is not installed
pytest.importorskip("psycopg")

from decisiongraph.domain.events import (  # noqa: E402
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
)
from decisiongraph.ids import generate_trace_id  # noqa: E402
from decisiongraph.projections import Projector  # noqa: E402
from decisiongraph.storage.postgres import PostgresEventStore  # noqa: E402
from decisiongraph.storage.sqlite import SQLiteEventStore  # noqa: E402
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
def sqlite_store() -> Iterator[SQLiteEventStore]:
    """Create an in-memory SQLite store.

    Yields:
        SQLiteEventStore instance
    """
    store = SQLiteEventStore(":memory:")
    yield store
    store.close()


@pytest.fixture
def postgres_store(pg_conninfo: str) -> Iterator[PostgresEventStore]:
    """Create a PostgreSQL store.

    Args:
        pg_conninfo: PostgreSQL connection string

    Yields:
        PostgresEventStore instance
    """
    store = PostgresEventStore(pg_conninfo)
    store.clear()
    yield store
    store.close()


def test_parity_get_trace_events(
    sqlite_store: SQLiteEventStore, postgres_store: PostgresEventStore
) -> None:
    """Test get_trace_events parity between SQLite and Postgres."""
    trace_id = generate_trace_id()

    # Create same events in both stores
    for i in range(5):
        event_type = (
            EVENT_TYPE_TRACE_STARTED if i == 0 else EVENT_TYPE_ENTITY_OBSERVED
        )
        payload = (
            {"workflow": "test", "title": "Parity test"}
            if i == 0
            else {"entity": {"entity_type": "Test", "entity_id": str(i)}}
        )

        env = create_test_envelope(
            trace_id=trace_id,
            trace_seq=i,
            event_type=event_type,
            payload=payload,
            idempotency_key=f"parity-{i}",
        )

        sqlite_store.append_event(env)
        postgres_store.append_event(env)

    # Get events from both stores
    sqlite_events = sqlite_store.get_trace_events(trace_id)
    postgres_events = postgres_store.get_trace_events(trace_id)

    # Verify same count
    assert len(sqlite_events) == len(postgres_events)

    # Verify same content (excluding log_seq which may differ)
    for sq_evt, pg_evt in zip(sqlite_events, postgres_events, strict=True):
        assert sq_evt.event_id == pg_evt.event_id
        assert sq_evt.trace_id == pg_evt.trace_id
        assert sq_evt.trace_seq == pg_evt.trace_seq
        assert sq_evt.event_type == pg_evt.event_type
        assert sq_evt.payload == pg_evt.payload
        assert sq_evt.payload_hash == pg_evt.payload_hash


def test_parity_list_events(
    sqlite_store: SQLiteEventStore, postgres_store: PostgresEventStore
) -> None:
    """Test list_events parity between SQLite and Postgres."""
    # Create multiple traces in both stores
    trace_ids = [generate_trace_id() for _ in range(3)]

    for idx, trace_id in enumerate(trace_ids):
        env = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": f"Trace {idx}"},
            idempotency_key=f"list-{idx}",
        )

        sqlite_store.append_event(env)
        postgres_store.append_event(env)

    # List all events
    sqlite_events = sqlite_store.list_events()
    postgres_events = postgres_store.list_events()

    # Verify same count
    assert len(sqlite_events) == len(postgres_events) == 3

    # Verify same event IDs (order may differ due to log_seq)
    sqlite_ids = {evt.event_id for evt in sqlite_events}
    postgres_ids = {evt.event_id for evt in postgres_events}
    assert sqlite_ids == postgres_ids


def test_parity_idempotency_behavior(
    sqlite_store: SQLiteEventStore, postgres_store: PostgresEventStore
) -> None:
    """Test idempotency behavior parity between SQLite and Postgres."""
    trace_id = generate_trace_id()
    payload = {"workflow": "test", "title": "Idempotency"}

    env = create_test_envelope(
        trace_id=trace_id,
        trace_seq=0,
        event_type=EVENT_TYPE_TRACE_STARTED,
        payload=payload,
        idempotency_key="idem-key",
    )

    # First append to both
    sq_stored1 = sqlite_store.append_event(env)
    pg_stored1 = postgres_store.append_event(env)

    # Second append (idempotent retry)
    sq_stored2 = sqlite_store.append_event(env)
    pg_stored2 = postgres_store.append_event(env)

    # Verify idempotency works the same way
    assert sq_stored1.log_seq == sq_stored2.log_seq
    assert pg_stored1.log_seq == pg_stored2.log_seq
    assert sq_stored1.payload_hash == pg_stored1.payload_hash


def test_pg_digest_matches_sqlite(
    sqlite_store: SQLiteEventStore, postgres_store: PostgresEventStore
) -> None:
    """TC-P4-006: Test that digest matches SQLite for same events."""
    trace_id = generate_trace_id()

    # Create a complete trace in both stores
    events_data = [
        (0, EVENT_TYPE_TRACE_STARTED, {"workflow": "test", "title": "Digest test"}),
        (
            1,
            EVENT_TYPE_ENTITY_OBSERVED,
            {"entity": {"entity_type": "User", "entity_id": "user1"}},
        ),
        (
            2,
            EVENT_TYPE_ENTITY_OBSERVED,
            {"entity": {"entity_type": "Order", "entity_id": "order1"}},
        ),
        (3, EVENT_TYPE_TRACE_FINISHED, {"outcome": "success"}),
    ]

    for trace_seq, event_type, payload in events_data:
        env = create_test_envelope(
            trace_id=trace_id,
            trace_seq=trace_seq,
            event_type=event_type,
            payload=payload,
            idempotency_key=f"digest-{trace_seq}",
        )

        sqlite_store.append_event(env)
        postgres_store.append_event(env)

    # Run projector on both stores
    sqlite_projector = Projector(sqlite_store)
    postgres_projector = Projector(postgres_store)

    sqlite_projector.run()
    postgres_projector.run()

    # Get digests from both
    sqlite_digest = sqlite_projector.get_digest()
    postgres_digest = postgres_projector.get_digest()

    # Verify digests match
    assert sqlite_digest == postgres_digest, (
        f"Digests should match!\n"
        f"SQLite: {sqlite_digest}\n"
        f"Postgres: {postgres_digest}"
    )


def test_parity_projector_digest(
    sqlite_store: SQLiteEventStore, postgres_store: PostgresEventStore
) -> None:
    """Test that projector produces same digest on both backends."""
    # Create multiple traces with various events
    for i in range(3):
        trace_id = generate_trace_id()

        # Start trace
        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": f"workflow-{i}", "title": f"Test {i}"},
            idempotency_key=f"proj-{i}-0",
        )
        sqlite_store.append_event(env0)
        postgres_store.append_event(env0)

        # Add entity observation
        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_ENTITY_OBSERVED,
            payload={"entity": {"entity_type": "Test", "entity_id": f"test-{i}"}},
            idempotency_key=f"proj-{i}-1",
        )
        sqlite_store.append_event(env1)
        postgres_store.append_event(env1)

        # Finish trace
        env2 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=2,
            event_type=EVENT_TYPE_TRACE_FINISHED,
            payload={"outcome": "success"},
            idempotency_key=f"proj-{i}-2",
        )
        sqlite_store.append_event(env2)
        postgres_store.append_event(env2)

    # Run projectors
    sqlite_projector = Projector(sqlite_store)
    postgres_projector = Projector(postgres_store)

    sqlite_projector.run()
    postgres_projector.run()

    # Compare digests
    sqlite_digest = sqlite_projector.get_digest()
    postgres_digest = postgres_projector.get_digest()

    assert sqlite_digest == postgres_digest


def test_parity_trace_finished_lock(
    sqlite_store: SQLiteEventStore, postgres_store: PostgresEventStore
) -> None:
    """Test that trace finished locking works identically."""
    trace_id = generate_trace_id()

    # Start and finish trace in both stores
    env0 = create_test_envelope(
        trace_id=trace_id,
        trace_seq=0,
        event_type=EVENT_TYPE_TRACE_STARTED,
        payload={"workflow": "test", "title": "Lock test"},
        idempotency_key="lock-0",
    )
    sqlite_store.append_event(env0)
    postgres_store.append_event(env0)

    env1 = create_test_envelope(
        trace_id=trace_id,
        trace_seq=1,
        event_type=EVENT_TYPE_TRACE_FINISHED,
        payload={"outcome": "success"},
        idempotency_key="lock-1",
    )
    sqlite_store.append_event(env1)
    postgres_store.append_event(env1)

    # Verify both are finished
    assert sqlite_store.is_trace_finished(trace_id)
    assert postgres_store.is_trace_finished(trace_id)

    # Verify next seq is consistent
    assert sqlite_store.get_next_trace_seq(trace_id) == 2
    assert postgres_store.get_next_trace_seq(trace_id) == 2
