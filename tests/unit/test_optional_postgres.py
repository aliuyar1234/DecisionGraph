"""Tests for PostgreSQL optional import behavior - TC-P4-010.

These tests verify that DecisionGraph can be imported and used
without psycopg installed, and that PostgresEventStore is available
when psycopg is installed.
"""

import sys

import pytest


def test_pg_optional_extra_import() -> None:
    """TC-P4-010: PostgreSQL is optional without breaking core imports."""
    # This test verifies the conditional import works

    # Import the storage module
    from decisiongraph.storage import HAS_POSTGRES, PostgresEventStore

    # Behavior depends on whether psycopg is installed
    try:
        import psycopg  # noqa: F401

        # If psycopg is installed, PostgresEventStore should be available
        assert HAS_POSTGRES is True
        assert PostgresEventStore is not None
        assert hasattr(PostgresEventStore, "__init__")
    except ImportError:
        # If psycopg is not installed, PostgresEventStore should be None
        assert HAS_POSTGRES is False
        assert PostgresEventStore is None


def test_import_without_psycopg() -> None:
    """Test graceful handling when psycopg is not installed."""
    try:
        import psycopg  # noqa: F401

        pytest.skip("psycopg installed")
    except ImportError:
        pass

    # Save original psycopg module if it exists
    original_psycopg = sys.modules.get("psycopg")

    try:
        # Mock psycopg as not installed
        if "psycopg" in sys.modules:
            del sys.modules["psycopg"]
        sys.modules["psycopg"] = None  # type: ignore

        # Force reimport of storage module
        if "decisiongraph.storage" in sys.modules:
            del sys.modules["decisiongraph.storage"]
        if "decisiongraph.storage.postgres" in sys.modules:
            del sys.modules["decisiongraph.storage.postgres"]

        # Import should work without psycopg
        from decisiongraph.storage import HAS_POSTGRES, SQLiteEventStore

        # SQLite should always be available
        assert SQLiteEventStore is not None

        # Postgres should not be available
        assert HAS_POSTGRES is False

    finally:
        # Restore original state
        if original_psycopg is not None:
            sys.modules["psycopg"] = original_psycopg
        elif "psycopg" in sys.modules:
            del sys.modules["psycopg"]

        # Force reimport to restore normal state
        for mod in list(sys.modules.keys()):
            if mod.startswith("decisiongraph.storage"):
                del sys.modules[mod]


def test_import_with_psycopg() -> None:
    """Test successful import when psycopg is installed."""
    try:
        import psycopg  # noqa: F401

        # Force reimport
        for mod in list(sys.modules.keys()):
            if mod.startswith("decisiongraph.storage"):
                del sys.modules[mod]

        from decisiongraph.storage import HAS_POSTGRES, PostgresEventStore

        assert HAS_POSTGRES is True
        assert PostgresEventStore is not None

    except ImportError:
        # If psycopg is not installed, skip this test
        pytest.skip("psycopg not installed")


def test_core_functionality_without_postgres() -> None:
    """Test that core functionality works without PostgreSQL."""
    from decisiongraph.domain.events import EVENT_TYPE_TRACE_STARTED
    from decisiongraph.ids import generate_trace_id
    from decisiongraph.storage.sqlite import SQLiteEventStore
    from decisiongraph.testing import create_test_envelope

    # Create SQLite store (should always work)
    store = SQLiteEventStore(":memory:")

    # Append event (core functionality)
    trace_id = generate_trace_id()
    env = create_test_envelope(
        trace_id=trace_id,
        trace_seq=0,
        event_type=EVENT_TYPE_TRACE_STARTED,
        payload={"workflow": "test", "title": "Test without Postgres"},
    )

    stored = store.append_event(env)
    assert stored.log_seq == 1

    # Retrieve event
    events = store.get_trace_events(trace_id)
    assert len(events) == 1

    store.close()
