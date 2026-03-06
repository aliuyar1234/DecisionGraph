"""E2E tests for CLI per SSOT P6.

Test cases TC-P6-007 and TC-P6-008.
"""

import json
from io import StringIO
from pathlib import Path
from unittest.mock import patch

import pytest

from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.testing.golden import load_fixture

FIXTURES_DIR = Path(__file__).parent.parent / "golden"


class TestCLI:
    """Tests for CLI commands."""

    def test_cli_replay_outputs_digest(self, tmp_path: Path) -> None:
        """TC-P6-007: CLI replay prints correct digest."""
        from decisiongraph.__main__ import cmd_replay

        # Create test database with renewal fixture
        db_path = tmp_path / "test.db"
        fixture = load_fixture(FIXTURES_DIR / "renewal")

        store = SQLiteEventStore(str(db_path))
        conn = store.connection
        projector = SQLiteProjector(conn)

        for envelope in fixture.events:
            store.append_event(envelope)

        projector.rebuild()
        all_events = store.list_events()
        projector.project_events(all_events)

        # Get expected digests
        from decisiongraph.projections.digests import (
            compute_context_graph_digest,
            compute_full_projection_digest,
            compute_precedent_index_digest,
            compute_trace_summary_digest,
        )

        expected_digests = {
            "context_graph": compute_context_graph_digest(conn),
            "trace_summary": compute_trace_summary_digest(conn),
            "precedent_index": compute_precedent_index_digest(conn),
            "full_projection": compute_full_projection_digest(conn),
        }

        store.close()

        # Test via direct function call (for coverage)
        with patch("sys.stdout", new_callable=StringIO) as mock_stdout:
            cmd_replay(str(db_path))
            output = mock_stdout.getvalue()

        # Verify digests in output
        for key, expected_digest in expected_digests.items():
            assert (
                expected_digest in output
            ), f"Expected digest {key}={expected_digest} in CLI output"

        assert "Projection digests after replay:" in output

    def test_cli_replay_does_not_mutate_source_db(self, tmp_path: Path) -> None:
        """replay should inspect a database without modifying stored projections."""
        from decisiongraph.__main__ import cmd_replay

        db_path = tmp_path / "test.db"
        fixture = load_fixture(FIXTURES_DIR / "renewal")
        store = SQLiteEventStore(str(db_path))

        for envelope in fixture.events:
            store.append_event(envelope)

        projection_tables = [
            "dg_cg_nodes",
            "dg_cg_edges",
            "dg_trace_summary",
            "dg_precedent_index",
            "dg_policy_eval_index",
            "dg_projection_meta",
        ]
        counts_before = {
            table: store.connection.execute(
                f"SELECT COUNT(*) AS count FROM {table}"
            ).fetchone()["count"]
            for table in projection_tables
        }
        event_count_before = store.connection.execute(
            "SELECT COUNT(*) AS count FROM dg_event_log"
        ).fetchone()["count"]
        store.close()

        cmd_replay(str(db_path))

        readonly = SQLiteEventStore(str(db_path), read_only=True)
        counts_after = {
            table: readonly.connection.execute(
                f"SELECT COUNT(*) AS count FROM {table}"
            ).fetchone()["count"]
            for table in projection_tables
        }
        event_count_after = readonly.connection.execute(
            "SELECT COUNT(*) AS count FROM dg_event_log"
        ).fetchone()["count"]
        readonly.close()

        assert counts_after == counts_before
        assert event_count_after == event_count_before

    def test_cli_dump_trace_stable(self, tmp_path: Path) -> None:
        """TC-P6-008: CLI dump-trace produces stable output."""
        from decisiongraph.__main__ import cmd_dump_trace

        # Create test database with renewal fixture
        db_path = tmp_path / "test.db"
        fixture = load_fixture(FIXTURES_DIR / "renewal")

        store = SQLiteEventStore(str(db_path))

        for envelope in fixture.events:
            store.append_event(envelope)

        store.close()

        # Test via direct function call (for coverage)
        with patch("sys.stdout", new_callable=StringIO) as mock_stdout:
            cmd_dump_trace(str(db_path), fixture.trace_id)
            output = mock_stdout.getvalue()

        # Parse JSON output
        events_data = json.loads(output)

        assert len(events_data) == 9, f"Expected 9 events, got {len(events_data)}"

        # Verify event order (trace_seq)
        for i, event in enumerate(events_data):
            assert event["trace_seq"] == i, f"Event {i} has wrong trace_seq"
            assert "payload" not in event
            assert "source" not in event
            assert "actor" not in event

        # Verify all events have the same trace_id
        for event in events_data:
            assert event["trace_id"] == fixture.trace_id

        # Run again and verify output is identical (deterministic)
        with patch("sys.stdout", new_callable=StringIO) as mock_stdout2:
            cmd_dump_trace(str(db_path), fixture.trace_id)
            output2 = mock_stdout2.getvalue()

        assert output == output2, "CLI dump-trace output is not deterministic"

    def test_cli_dump_trace_include_payload_opt_in(self, tmp_path: Path) -> None:
        """dump-trace includes payload only when explicitly requested."""
        from decisiongraph.__main__ import cmd_dump_trace

        db_path = tmp_path / "test.db"
        fixture = load_fixture(FIXTURES_DIR / "renewal")
        store = SQLiteEventStore(str(db_path))
        for envelope in fixture.events:
            store.append_event(envelope)
        store.close()

        with patch("sys.stdout", new_callable=StringIO) as mock_stdout:
            cmd_dump_trace(str(db_path), fixture.trace_id, include_payload=True)
            events_data = json.loads(mock_stdout.getvalue())

        assert len(events_data) == 9
        for event in events_data:
            assert "payload" in event
            assert "source" in event
            assert "actor" in event

    def test_cli_projection_status_reports_health(self, tmp_path: Path) -> None:
        """projection-status prints deterministic projection health JSON."""
        from decisiongraph.__main__ import cmd_projection_status

        db_path = tmp_path / "status.db"
        fixture = load_fixture(FIXTURES_DIR / "renewal")
        store = SQLiteEventStore(str(db_path))
        for envelope in fixture.events:
            store.append_event(envelope)
        store.close()

        with patch("sys.stdout", new_callable=StringIO) as mock_stdout:
            cmd_projection_status(str(db_path))
            status = json.loads(mock_stdout.getvalue())

        assert status["is_stale"] is True
        assert status["pending_events"] == status["event_log_last_seq"]
        assert status["digests"] is None

    def test_cli_projection_status_include_digests(self, tmp_path: Path) -> None:
        """projection-status can include current projection digests."""
        from decisiongraph.__main__ import cmd_projection_status

        db_path = tmp_path / "status.db"
        fixture = load_fixture(FIXTURES_DIR / "renewal")
        store = SQLiteEventStore(str(db_path))
        conn = store.connection
        projector = SQLiteProjector(conn)
        for envelope in fixture.events:
            store.append_event(envelope)
        projector.rebuild()
        projector.project_events(store.list_events())
        store.close()

        with patch("sys.stdout", new_callable=StringIO) as mock_stdout:
            cmd_projection_status(str(db_path), include_digests=True)
            status = json.loads(mock_stdout.getvalue())

        assert status["is_stale"] is False
        assert set(status["digests"]) == {
            "context_graph",
            "trace_summary",
            "precedent_index",
            "full_projection",
        }

    def test_cli_replay_missing_db(self) -> None:
        """Test CLI replay with missing database."""
        from decisiongraph.__main__ import cmd_replay

        with pytest.raises(SystemExit) as exc_info:
            cmd_replay("/nonexistent/db.db")

        assert exc_info.value.code == 1

    def test_cli_dump_trace_missing_db(self) -> None:
        """Test CLI dump-trace with missing database."""
        from decisiongraph.__main__ import cmd_dump_trace

        with pytest.raises(SystemExit) as exc_info:
            cmd_dump_trace("/nonexistent/db.db", "fake-trace-id")

        assert exc_info.value.code == 1

    def test_cli_dump_trace_nonexistent_trace(self, tmp_path: Path) -> None:
        """Test CLI dump-trace with nonexistent trace."""
        from decisiongraph.__main__ import cmd_dump_trace

        db_path = tmp_path / "empty.db"
        store = SQLiteEventStore(str(db_path))
        store.close()

        with pytest.raises(SystemExit) as exc_info:
            cmd_dump_trace(str(db_path), "nonexistent-trace-id")

        assert exc_info.value.code == 1

    def test_cli_dump_trace_read_only_no_migrations(self, tmp_path: Path) -> None:
        """dump-trace should not apply migrations or mutate DB."""
        from decisiongraph.__main__ import cmd_dump_trace

        db_path = tmp_path / "empty.db"
        db_path.write_bytes(b"")

        with pytest.raises(SystemExit):
            cmd_dump_trace(str(db_path), "trace-does-not-exist")

        import sqlite3

        conn = sqlite3.connect(str(db_path))
        tables = {
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            ).fetchall()
        }
        conn.close()

        assert "schema_migrations" not in tables

    def test_cli_projection_status_read_only_no_migrations(self, tmp_path: Path) -> None:
        """projection-status should not apply migrations or mutate DB."""
        from decisiongraph.__main__ import cmd_projection_status

        db_path = tmp_path / "empty.db"
        db_path.write_bytes(b"")

        with pytest.raises(SystemExit):
            cmd_projection_status(str(db_path))

        import sqlite3

        conn = sqlite3.connect(str(db_path))
        tables = {
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            ).fetchall()
        }
        conn.close()

        assert "schema_migrations" not in tables
