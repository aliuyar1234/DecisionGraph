"""High-contention multi-writer integration tests for v1 hardening."""

from __future__ import annotations

import os
import threading
import time
from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

import pytest

from decisiongraph.domain.events import (
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
)
from decisiongraph.errors import (
    DG_ERR_CONFLICT,
    DG_ERR_EVENT_SEQUENCE_INVALID,
    DG_ERR_STORAGE,
    DecisionGraphError,
)
from decisiongraph.ids import generate_trace_id
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.testing import create_test_envelope

RETRYABLE_CONTENTION_CODES = {
    DG_ERR_EVENT_SEQUENCE_INVALID,
    DG_ERR_STORAGE,
}


def _append_trace_started(factory: Callable[[], Any], trace_id: str) -> None:
    with factory() as store:
        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "contention", "title": "high contention"},
        )
        store.append_event(env0)


def _append_entity_with_retry(
    factory: Callable[[], Any],
    trace_id: str,
    idempotency_key: str,
    payload_suffix: str,
    *,
    max_attempts: int = 500,
    fixed_trace_seq: int | None = None,
) -> int:
    with factory() as store:
        for attempt in range(max_attempts):
            trace_seq = (
                fixed_trace_seq
                if fixed_trace_seq is not None
                else store.get_next_trace_seq(trace_id)
            )
            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=trace_seq,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={
                    "entity": {
                        "entity_type": "account",
                        "entity_id": f"acct-{payload_suffix}",
                    },
                    "role": "related",
                    "facts": [],
                },
                idempotency_key=idempotency_key,
            )

            try:
                return store.append_event(env).trace_seq
            except DecisionGraphError as exc:
                if exc.code in RETRYABLE_CONTENTION_CODES:
                    time.sleep(0.001 * ((attempt % 5) + 1))
                    continue
                raise

    raise AssertionError(f"failed to append after {max_attempts} attempts")


def _append_finish_with_retry(
    factory: Callable[[], Any], trace_id: str, *, max_attempts: int = 500
) -> int:
    with factory() as store:
        for attempt in range(max_attempts):
            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=store.get_next_trace_seq(trace_id),
                event_type=EVENT_TYPE_TRACE_FINISHED,
                payload={"outcome": "success"},
                idempotency_key=f"finish:{trace_id}",
            )
            try:
                return store.append_event(env).trace_seq
            except DecisionGraphError as exc:
                if exc.code in RETRYABLE_CONTENTION_CODES:
                    time.sleep(0.001 * ((attempt % 5) + 1))
                    continue
                if exc.code == DG_ERR_CONFLICT:
                    # If another retry already finished, treat as complete.
                    return store.get_next_trace_seq(trace_id) - 1
                raise

    raise AssertionError(f"failed to finish trace after {max_attempts} attempts")


class TestSQLiteHighContention:
    """High-contention behavior for SQLite backend."""

    def test_sqlite_idempotency_under_high_contention(self, tmp_path: Path) -> None:
        db_path = tmp_path / "sqlite-idempotency-contention.db"
        trace_id = generate_trace_id()

        def factory() -> SQLiteEventStore:
            return SQLiteEventStore(str(db_path))

        _append_trace_started(factory, trace_id)

        def worker(_worker_id: int) -> int:
            return _append_entity_with_retry(
                factory,
                trace_id,
                idempotency_key="idem:shared-key",
                payload_suffix="shared",
                fixed_trace_seq=1,
            )

        with ThreadPoolExecutor(max_workers=24) as pool:
            results = list(pool.map(worker, range(24)))

        assert len(set(results)) == 1

        with factory() as store:
            events = store.get_trace_events(trace_id)
            assert [event.trace_seq for event in events] == [0, 1]

    def test_sqlite_trace_seq_under_high_contention(self, tmp_path: Path) -> None:
        db_path = tmp_path / "sqlite-trace-seq-contention.db"
        trace_id = generate_trace_id()

        def factory() -> SQLiteEventStore:
            return SQLiteEventStore(str(db_path))

        _append_trace_started(factory, trace_id)

        writer_count = 40

        def worker(worker_id: int) -> int:
            return _append_entity_with_retry(
                factory,
                trace_id,
                idempotency_key=f"seq:{worker_id}",
                payload_suffix=str(worker_id),
            )

        with ThreadPoolExecutor(max_workers=16) as pool:
            worker_trace_seqs = list(pool.map(worker, range(writer_count)))

        assert len(set(worker_trace_seqs)) == writer_count

        with factory() as store:
            events = store.get_trace_events(trace_id)
            assert len(events) == writer_count + 1
            assert [event.trace_seq for event in events] == list(range(writer_count + 1))

    def test_sqlite_finish_lock_under_high_contention(self, tmp_path: Path) -> None:
        db_path = tmp_path / "sqlite-finish-lock-contention.db"
        trace_id = generate_trace_id()

        def factory() -> SQLiteEventStore:
            return SQLiteEventStore(str(db_path))

        _append_trace_started(factory, trace_id)

        stop = threading.Event()

        def writer(worker_id: int) -> None:
            for attempt in range(120):
                if stop.is_set():
                    return
                try:
                    _append_entity_with_retry(
                        factory,
                        trace_id,
                        idempotency_key=f"writer:{worker_id}:{attempt}",
                        payload_suffix=f"{worker_id}-{attempt}",
                        max_attempts=80,
                    )
                except DecisionGraphError as exc:
                    if exc.code == DG_ERR_CONFLICT:
                        stop.set()
                        return
                    raise

        with ThreadPoolExecutor(max_workers=12) as pool:
            finish_future = pool.submit(_append_finish_with_retry, factory, trace_id)
            writer_futures = [pool.submit(writer, worker_id) for worker_id in range(10)]

            finish_seq = finish_future.result(timeout=30)
            stop.set()
            for future in writer_futures:
                future.result(timeout=30)

        with factory() as store:
            events = store.get_trace_events(trace_id)
            finish_events = [
                event for event in events if event.event_type == EVENT_TYPE_TRACE_FINISHED
            ]
            assert len(finish_events) == 1
            assert finish_events[0].trace_seq == finish_seq
            assert all(
                event.event_type == EVENT_TYPE_TRACE_FINISHED
                for event in events
                if event.trace_seq >= finish_seq
            )

            late_env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=store.get_next_trace_seq(trace_id),
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={
                    "entity": {"entity_type": "account", "entity_id": "late"},
                    "role": "related",
                    "facts": [],
                },
                idempotency_key="late-write",
            )
            with pytest.raises(DecisionGraphError) as exc_info:
                store.append_event(late_env)
            assert exc_info.value.code == DG_ERR_CONFLICT


@pytest.fixture
def pg_conninfo() -> str:
    pytest.importorskip("psycopg", exc_type=ImportError)
    conninfo = os.getenv("PG_CONNINFO")
    if not conninfo:
        pytest.skip("PG_CONNINFO environment variable not set")
    return conninfo


class TestPostgresHighContention:
    """High-contention behavior for PostgreSQL backend."""

    def test_postgres_idempotency_under_high_contention(self, pg_conninfo: str) -> None:
        from decisiongraph.storage.postgres import PostgresEventStore

        with PostgresEventStore(pg_conninfo) as clean:
            clean.clear()

        def factory() -> Any:
            return PostgresEventStore(pg_conninfo)

        trace_id = generate_trace_id()
        _append_trace_started(factory, trace_id)

        def worker(_worker_id: int) -> int:
            return _append_entity_with_retry(
                factory,
                trace_id,
                idempotency_key="idem:shared-key",
                payload_suffix="shared",
                fixed_trace_seq=1,
            )

        with ThreadPoolExecutor(max_workers=24) as pool:
            results = list(pool.map(worker, range(24)))

        assert len(set(results)) == 1

        with factory() as store:
            events = store.get_trace_events(trace_id)
            assert [event.trace_seq for event in events] == [0, 1]

    def test_postgres_trace_seq_under_high_contention(self, pg_conninfo: str) -> None:
        from decisiongraph.storage.postgres import PostgresEventStore

        with PostgresEventStore(pg_conninfo) as clean:
            clean.clear()

        def factory() -> Any:
            return PostgresEventStore(pg_conninfo)

        trace_id = generate_trace_id()
        _append_trace_started(factory, trace_id)
        writer_count = 32

        def worker(worker_id: int) -> int:
            return _append_entity_with_retry(
                factory,
                trace_id,
                idempotency_key=f"seq:{worker_id}",
                payload_suffix=str(worker_id),
            )

        with ThreadPoolExecutor(max_workers=16) as pool:
            worker_trace_seqs = list(pool.map(worker, range(writer_count)))

        assert len(set(worker_trace_seqs)) == writer_count

        with factory() as store:
            events = store.get_trace_events(trace_id)
            assert len(events) == writer_count + 1
            assert [event.trace_seq for event in events] == list(range(writer_count + 1))

    def test_postgres_finish_lock_under_high_contention(self, pg_conninfo: str) -> None:
        from decisiongraph.storage.postgres import PostgresEventStore

        with PostgresEventStore(pg_conninfo) as clean:
            clean.clear()

        def factory() -> Any:
            return PostgresEventStore(pg_conninfo)

        trace_id = generate_trace_id()
        _append_trace_started(factory, trace_id)
        stop = threading.Event()

        def writer(worker_id: int) -> None:
            for attempt in range(120):
                if stop.is_set():
                    return
                try:
                    _append_entity_with_retry(
                        factory,
                        trace_id,
                        idempotency_key=f"writer:{worker_id}:{attempt}",
                        payload_suffix=f"{worker_id}-{attempt}",
                        max_attempts=80,
                    )
                except DecisionGraphError as exc:
                    if exc.code == DG_ERR_CONFLICT:
                        stop.set()
                        return
                    raise

        with ThreadPoolExecutor(max_workers=12) as pool:
            finish_future = pool.submit(_append_finish_with_retry, factory, trace_id)
            writer_futures = [pool.submit(writer, worker_id) for worker_id in range(10)]

            finish_seq = finish_future.result(timeout=30)
            stop.set()
            for future in writer_futures:
                future.result(timeout=30)

        with factory() as store:
            events = store.get_trace_events(trace_id)
            finish_events = [
                event for event in events if event.event_type == EVENT_TYPE_TRACE_FINISHED
            ]
            assert len(finish_events) == 1
            assert finish_events[0].trace_seq == finish_seq
            assert all(
                event.event_type == EVENT_TYPE_TRACE_FINISHED
                for event in events
                if event.trace_seq >= finish_seq
            )

            late_env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=store.get_next_trace_seq(trace_id),
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={
                    "entity": {"entity_type": "account", "entity_id": "late"},
                    "role": "related",
                    "facts": [],
                },
                idempotency_key="late-write",
            )
            with pytest.raises(DecisionGraphError) as exc_info:
                store.append_event(late_env)
            assert exc_info.value.code == DG_ERR_CONFLICT
