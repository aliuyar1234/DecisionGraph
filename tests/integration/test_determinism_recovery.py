"""Determinism and crash-recovery integration tests for v1 hardening."""

from __future__ import annotations

import sqlite3
from pathlib import Path

import pytest

from decisiongraph import DecisionGraph
from decisiongraph.domain.events import (
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_TRACE_STARTED,
)
from decisiongraph.domain.types import ActorRef, EntityRef, SourceRef
from decisiongraph.ids import generate_trace_id
from decisiongraph.projections.digests import (
    compute_context_graph_digest,
    compute_full_projection_digest,
    compute_precedent_index_digest,
    compute_trace_summary_digest,
)
from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.storage.migrations import MigrationEngine
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.testing import create_test_envelope
from decisiongraph.testing.golden import GoldenFixture, load_fixture

FIXTURES_DIR = Path(__file__).parent.parent / "golden"


def _load_all_fixtures() -> list[GoldenFixture]:
    scenarios = ("dealdesk", "renewal", "support")
    return [load_fixture(FIXTURES_DIR / scenario) for scenario in scenarios]


def _append_fixtures(store: SQLiteEventStore, fixtures: list[GoldenFixture]) -> None:
    for fixture in fixtures:
        for envelope in fixture.events:
            store.append_event(envelope)


def _compute_projection_digests(conn: sqlite3.Connection) -> dict[str, str]:
    return {
        "context_graph": compute_context_graph_digest(conn),
        "trace_summary": compute_trace_summary_digest(conn),
        "precedent_index": compute_precedent_index_digest(conn),
        "full_projection": compute_full_projection_digest(conn),
    }


def _rebuild_and_digest(store: SQLiteEventStore) -> dict[str, str]:
    projector = SQLiteProjector(store.connection)
    projector.rebuild()
    projector.project_events(store.list_events())
    return _compute_projection_digests(store.connection)


def _create_db_at_migration_version(db_path: Path, target_version: int) -> int:
    migrations_dir = Path(__file__).parents[2] / "src" / "decisiongraph" / "storage" / "sqlite" / "migrations"
    conn = sqlite3.connect(str(db_path))
    try:
        engine = MigrationEngine(conn, migrations_dir)
        migrations = engine.discover_migrations()
        latest_version = migrations[-1].version if migrations else 0
        for migration in migrations:
            if migration.version <= target_version:
                engine.apply_migration(migration)
        return latest_version
    finally:
        conn.close()


class TestMigrationCompatibilityMatrix:
    """Verify replay compatibility from each historical migration version."""

    def test_sqlite_replay_digest_stable_from_all_historical_versions(
        self, tmp_path: Path
    ) -> None:
        fixtures = _load_all_fixtures()

        baseline_db = tmp_path / "baseline-latest.db"
        with SQLiteEventStore(str(baseline_db)) as baseline_store:
            _append_fixtures(baseline_store, fixtures)
            expected = _rebuild_and_digest(baseline_store)

        latest_version = _create_db_at_migration_version(
            tmp_path / "discover-version.db", target_version=10_000
        )

        for start_version in range(0, latest_version + 1):
            db_path = tmp_path / f"from-v{start_version}.db"
            _create_db_at_migration_version(db_path, target_version=start_version)

            with SQLiteEventStore(str(db_path)) as store:
                current_version = store.connection.execute(
                    "SELECT MAX(version) AS version FROM schema_migrations"
                ).fetchone()["version"]
                assert int(current_version) == latest_version

                _append_fixtures(store, fixtures)
                actual = _rebuild_and_digest(store)

            assert actual == expected, (
                f"Digest mismatch after migrate/replay from version {start_version}: "
                f"expected {expected}, got {actual}"
            )


class TestCrashRecovery:
    """Verify append/projection crash boundaries recover deterministically."""

    def test_project_events_transaction_rollback_on_mid_batch_failure(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        db_path = tmp_path / "projection-crash.db"
        trace_id = generate_trace_id()

        with SQLiteEventStore(str(db_path)) as store:
            env0 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "crash-test", "title": "Crash recovery"},
            )
            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={
                    "entity": {"entity_type": "account", "entity_id": "acct-1"},
                    "role": "primary",
                    "facts": [],
                },
            )
            event0 = store.append_event(env0)
            event1 = store.append_event(env1)

            projector = SQLiteProjector(store.connection)
            original_project = projector._project_event_in_tx
            call_count = 0

            def crash_second(event) -> None:
                nonlocal call_count
                call_count += 1
                if call_count == 2:
                    raise RuntimeError("simulated projector crash")
                original_project(event)

            monkeypatch.setattr(projector, "_project_event_in_tx", crash_second)

            with pytest.raises(RuntimeError, match="simulated projector crash"):
                projector.project_events([event0, event1])

            assert projector.get_cursor() == 0
            assert projector.get_nodes(trace_id) == []
            assert projector.get_edges(trace_id) == []

        with SQLiteEventStore(str(db_path)) as recovered_store:
            recovered_projector = SQLiteProjector(recovered_store.connection)
            recovered_projector.project_events(recovered_store.list_events())
            assert recovered_projector.get_cursor() == 2
            assert len(recovered_projector.get_nodes(trace_id)) > 0

    def test_api_append_projection_boundary_recovers_on_restart(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        db_path = tmp_path / "append-projection-boundary.db"
        source = SourceRef(producer_id="recovery-test", system="tests")
        actor = ActorRef(actor_type="agent", actor_id="agent-v1")
        entity = EntityRef(entity_type="account", entity_id="acct-42", system="crm")

        with DecisionGraph(str(db_path)) as dg:
            original_project_through = dg._project_through_log_seq

            def crash_after_append(_target_log_seq: int) -> None:
                raise RuntimeError("simulated crash after append before projection")

            monkeypatch.setattr(dg, "_project_through_log_seq", crash_after_append)

            with pytest.raises(RuntimeError, match="simulated crash after append"):
                dg.start_trace(
                    workflow="renewal",
                    title="Boundary crash test",
                    primary_entity=entity,
                    source=source,
                    actor=actor,
                )

            events = dg._store.list_events()
            assert len(events) == 1
            assert events[0].event_type == EVENT_TYPE_TRACE_STARTED
            assert dg._projector.get_cursor() == 0

            monkeypatch.setattr(dg, "_project_through_log_seq", original_project_through)

        with DecisionGraph(str(db_path)) as recovered:
            processed = recovered.sync_projections()
            assert processed == 1
            assert recovered._projector.get_cursor() == recovered._store.get_last_log_seq()
