"""SQLite event store implementation.

This module provides SQLiteEventStore, which implements the EventStore protocol
using SQLite as the persistence layer.
"""

import contextlib
import sqlite3
from collections.abc import Iterator
from pathlib import Path
from typing import Any

from decisiongraph.domain.events import (
    EVENT_TYPE_TRACE_FINISHED,
    EventEnvelope,
    StoredEvent,
)
from decisiongraph.errors import (
    DG_ERR_CONFLICT,
    DG_ERR_EVENT_SEQUENCE_INVALID,
    DG_ERR_IDEMPOTENCY_CONFLICT,
    DG_ERR_INVALID_ARGUMENT,
    DG_ERR_STORAGE,
    DecisionGraphError,
)
from decisiongraph.storage._shared import (
    prepare_event_for_insert,
    row_to_stored_event,
    validate_idempotent_reuse,
    validate_trace_seq,
)
from decisiongraph.storage.migrations import MigrationEngine


class SQLiteEventStore:
    """SQLite implementation of EventStore protocol.

    This class provides persistent event storage using SQLite.
    It implements the EventStore protocol per SSOT 11.6.

    Features:
    - Automatic schema migration on initialization
    - Idempotency enforcement via UNIQUE constraint
    - trace_seq monotonicity enforcement
    - TraceFinished locks traces
    - PII guard on payloads

    Usage:
        store = SQLiteEventStore(":memory:")  # In-memory for tests
        store = SQLiteEventStore("events.db")  # File-based for production
    """

    def __init__(self, db_path: str | Path, *, read_only: bool = False) -> None:
        """Initialize SQLite event store.

        Args:
            db_path: Path to SQLite database file, or ":memory:" for in-memory
        """
        self._db_path = str(db_path) if isinstance(db_path, Path) else db_path
        self._read_only = read_only

        if read_only:
            if self._db_path == ":memory:":
                raise ValueError("read_only is not supported for in-memory databases")
            uri = f"file:{self._db_path}?mode=ro"
            self._conn = sqlite3.connect(uri, uri=True)
        else:
            self._conn = sqlite3.connect(self._db_path)
        self._conn.row_factory = sqlite3.Row

        # Enable foreign keys and WAL mode for better concurrency
        self._conn.execute("PRAGMA foreign_keys = ON")
        if not read_only and self._db_path != ":memory:":
            self._conn.execute("PRAGMA journal_mode = WAL")
        if read_only:
            self._conn.execute("PRAGMA query_only = ON")

        # Run migrations (skip for read-only)
        if not read_only:
            self._migrate()

    def _get_migrations_dir(self) -> Path:
        """Get the migrations directory path."""
        return Path(__file__).parent / "migrations"

    def _migrate(self) -> None:
        """Apply pending database migrations."""
        engine = MigrationEngine(self._conn, self._get_migrations_dir())
        engine.migrate()

    def close(self) -> None:
        """Close the database connection."""
        self._conn.close()

    @property
    def connection(self) -> sqlite3.Connection:
        """Get the database connection (read-only for external usage)."""
        return self._conn

    def __enter__(self) -> "SQLiteEventStore":
        """Context manager entry."""
        return self

    def __exit__(self, exc_type: Any, exc_val: Any, exc_tb: Any) -> None:
        """Context manager exit - close connection."""
        self.close()

    def append_event(self, envelope: EventEnvelope) -> StoredEvent:
        """Append event to the store.

        Args:
            envelope: Event envelope to append

        Returns:
            StoredEvent with assigned log_seq, recorded_at, and payload_hash

        Raises:
            DecisionGraphError: With appropriate error code
        """
        # Validate and prepare event data (shared logic)
        prepared = prepare_event_for_insert(envelope)

        try:
            # Check for idempotent retry first
            existing = self._check_idempotency(envelope, prepared.payload_hash)
            if existing is not None:
                return existing

            # Check if trace is finished
            if self.is_trace_finished(envelope.trace_id):
                raise DecisionGraphError(
                    DG_ERR_CONFLICT,
                    f"Trace '{envelope.trace_id}' is already finished",
                )

            # Validate trace_seq rules (shared logic)
            expected_seq = self.get_next_trace_seq(envelope.trace_id)
            validate_trace_seq(envelope, expected_seq)

            # Insert event
            cursor = self._conn.execute(
                """
                INSERT INTO dg_event_log (
                    event_id, trace_id, trace_seq, event_type,
                    occurred_at, recorded_at,
                    producer_id, system, subsystem,
                    actor_type, actor_id,
                    correlation_id, causation_event_id,
                    idempotency_key, schema_version,
                    payload_json, payload_hash, tags_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    envelope.event_id,
                    envelope.trace_id,
                    envelope.trace_seq,
                    envelope.event_type,
                    envelope.occurred_at,
                    prepared.recorded_at,
                    envelope.source.producer_id,
                    envelope.source.system,
                    envelope.source.subsystem,
                    envelope.actor.actor_type,
                    envelope.actor.actor_id,
                    envelope.correlation_id,
                    envelope.causation_event_id,
                    envelope.idempotency_key,
                    envelope.schema_version,
                    prepared.payload_json,
                    prepared.payload_hash,
                    prepared.tags_json,
                ),
            )
            self._conn.commit()

            log_seq = cursor.lastrowid
            if log_seq is None:
                raise DecisionGraphError(
                    DG_ERR_STORAGE, "Failed to get log_seq after insert"
                )

            return StoredEvent(
                log_seq=log_seq,
                event_id=envelope.event_id,
                trace_id=envelope.trace_id,
                trace_seq=envelope.trace_seq,
                event_type=envelope.event_type,
                occurred_at=envelope.occurred_at,
                recorded_at=prepared.recorded_at,
                source=envelope.source,
                actor=envelope.actor,
                idempotency_key=envelope.idempotency_key,
                payload=envelope.payload,
                payload_hash=prepared.payload_hash,
                correlation_id=envelope.correlation_id,
                causation_event_id=envelope.causation_event_id,
                schema_version=envelope.schema_version,
                tags=list(envelope.tags),
            )

        except sqlite3.IntegrityError as e:
            self._conn.rollback()
            error_str = str(e).lower()
            if "trace_finished" in error_str:
                raise DecisionGraphError(
                    DG_ERR_CONFLICT,
                    f"Trace '{envelope.trace_id}' is already finished",
                ) from e
            if "idempotency" in error_str:
                # Handle races where another writer inserted the same
                # idempotency key after our pre-check.
                existing = self._check_idempotency(envelope, prepared.payload_hash)
                if existing is not None:
                    return existing
                raise DecisionGraphError(
                    DG_ERR_IDEMPOTENCY_CONFLICT,
                    f"Idempotency key '{envelope.idempotency_key}' already used",
                ) from e
            if "trace_seq" in error_str or "idx_event_log_trace_seq" in error_str:
                raise DecisionGraphError(
                    DG_ERR_EVENT_SEQUENCE_INVALID,
                    f"trace_seq {envelope.trace_seq} already exists for trace",
                ) from e
            raise DecisionGraphError(DG_ERR_STORAGE, f"Database error: {e}") from e
        except sqlite3.Error as e:
            self._conn.rollback()
            error_str = str(e).lower()
            if "trace_finished" in error_str:
                raise DecisionGraphError(
                    DG_ERR_CONFLICT,
                    f"Trace '{envelope.trace_id}' is already finished",
                ) from e
            raise DecisionGraphError(DG_ERR_STORAGE, f"Database error: {e}") from e

    def _check_idempotency(
        self, envelope: EventEnvelope, payload_hash: str
    ) -> StoredEvent | None:
        """Check for idempotent retry.

        Args:
            envelope: Event envelope to check
            payload_hash: Computed payload hash

        Returns:
            Existing StoredEvent if idempotent retry, None otherwise

        Raises:
            DecisionGraphError: If idempotency key used with different payload
        """
        cursor = self._conn.execute(
            """
            SELECT * FROM dg_event_log
            WHERE producer_id = ? AND idempotency_key = ?
            """,
            (envelope.source.producer_id, envelope.idempotency_key),
        )
        row = cursor.fetchone()

        if row is None:
            return None

        return validate_idempotent_reuse(envelope, row, payload_hash)

    def get_trace_events(
        self,
        trace_id: str,
        since_trace_seq: int | None = None,
        limit: int | None = None,
    ) -> list[StoredEvent]:
        """Get events for a trace, ordered by trace_seq.

        Args:
            trace_id: Trace ID to get events for
            since_trace_seq: Only return events with trace_seq > this value
            limit: Maximum number of events to return

        Returns:
            List of stored events ordered by trace_seq
        """
        query = "SELECT * FROM dg_event_log WHERE trace_id = ?"
        params: list[Any] = [trace_id]

        if since_trace_seq is not None:
            query += " AND trace_seq > ?"
            params.append(since_trace_seq)

        query += " ORDER BY trace_seq ASC"

        if limit is not None:
            query += " LIMIT ?"
            params.append(limit)

        cursor = self._conn.execute(query, params)
        return [row_to_stored_event(row) for row in cursor.fetchall()]

    def list_events(
        self,
        since_log_seq: int | None = None,
        until_log_seq: int | None = None,
        event_type: str | None = None,
        trace_id: str | None = None,
        limit: int | None = None,
    ) -> list[StoredEvent]:
        """List events from the global log, ordered by log_seq.

        Args:
            since_log_seq: Only return events with log_seq > this value
            until_log_seq: Only return events with log_seq <= this value
            event_type: Filter by event type
            trace_id: Filter by trace ID
            limit: Maximum number of events to return

        Returns:
            List of stored events ordered by log_seq
        """
        query = "SELECT * FROM dg_event_log WHERE 1=1"
        params: list[Any] = []

        if since_log_seq is not None:
            query += " AND log_seq > ?"
            params.append(since_log_seq)
        if until_log_seq is not None:
            query += " AND log_seq <= ?"
            params.append(until_log_seq)
        if event_type is not None:
            query += " AND event_type = ?"
            params.append(event_type)
        if trace_id is not None:
            query += " AND trace_id = ?"
            params.append(trace_id)

        query += " ORDER BY log_seq ASC"

        if limit is not None:
            query += " LIMIT ?"
            params.append(limit)

        cursor = self._conn.execute(query, params)
        return [row_to_stored_event(row) for row in cursor.fetchall()]

    def iter_event_batches(
        self,
        since_log_seq: int | None = None,
        until_log_seq: int | None = None,
        event_type: str | None = None,
        trace_id: str | None = None,
        batch_size: int = 1000,
    ) -> Iterator[list[StoredEvent]]:
        """Iterate through event-log pages in ascending log_seq order."""
        if batch_size <= 0:
            raise DecisionGraphError(
                DG_ERR_INVALID_ARGUMENT,
                "batch_size must be positive",
            )

        cursor = since_log_seq
        while True:
            batch = self.list_events(
                since_log_seq=cursor,
                until_log_seq=until_log_seq,
                event_type=event_type,
                trace_id=trace_id,
                limit=batch_size,
            )
            if not batch:
                return

            yield batch
            cursor = batch[-1].log_seq

            if until_log_seq is not None and cursor >= until_log_seq:
                return

    def get_last_log_seq(self) -> int:
        """Get the current maximum log_seq.

        Returns:
            Maximum log_seq in the store, or 0 if empty
        """
        cursor = self._conn.execute("SELECT MAX(log_seq) FROM dg_event_log")
        row = cursor.fetchone()
        return row[0] if row[0] is not None else 0

    def is_trace_finished(self, trace_id: str) -> bool:
        """Check if a trace has been finished.

        Args:
            trace_id: Trace ID to check

        Returns:
            True if TraceFinished event exists for this trace
        """
        cursor = self._conn.execute(
            """
            SELECT 1 FROM dg_event_log
            WHERE trace_id = ? AND event_type = ?
            LIMIT 1
            """,
            (trace_id, EVENT_TYPE_TRACE_FINISHED),
        )
        return cursor.fetchone() is not None

    def get_next_trace_seq(self, trace_id: str) -> int:
        """Get the next expected trace_seq for a trace.

        Args:
            trace_id: Trace ID to check

        Returns:
            Next expected trace_seq (max existing + 1, or 0 if no events)
        """
        cursor = self._conn.execute(
            "SELECT MAX(trace_seq) FROM dg_event_log WHERE trace_id = ?",
            (trace_id,),
        )
        row = cursor.fetchone()
        if row[0] is None:
            return 0
        return int(row[0]) + 1

    def clear(self) -> None:
        """Clear all stored events.

        Useful for test isolation.
        """
        self._conn.execute("DELETE FROM dg_event_log")
        # Reset the ROWID counter by updating sqlite_sequence if it exists
        # (only exists when AUTOINCREMENT is used, but we try anyway)
        with contextlib.suppress(sqlite3.OperationalError):
            self._conn.execute(
                "DELETE FROM sqlite_sequence WHERE name = 'dg_event_log'"
            )
        self._conn.commit()


__all__ = ["SQLiteEventStore"]
