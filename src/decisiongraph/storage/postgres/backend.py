"""PostgreSQL event store implementation.

This module provides PostgresEventStore, which implements the EventStore protocol
using PostgreSQL as the persistence layer.
"""

import re
from pathlib import Path
from typing import Any

try:
    import psycopg  # type: ignore[import-not-found]
    from psycopg import Connection
    from psycopg.rows import dict_row  # type: ignore[import-not-found]
except ImportError as e:
    raise ImportError(
        "psycopg is required for PostgreSQL support. "
        "Install with: pip install decisiongraph[postgres]"
    ) from e

from decisiongraph.domain.events import (
    EVENT_TYPE_TRACE_FINISHED,
    EventEnvelope,
    StoredEvent,
)
from decisiongraph.errors import (
    DG_ERR_CONFLICT,
    DG_ERR_EVENT_SEQUENCE_INVALID,
    DG_ERR_IDEMPOTENCY_CONFLICT,
    DG_ERR_STORAGE,
    DecisionGraphError,
)
from decisiongraph.storage._shared import (
    prepare_event_for_insert,
    row_to_stored_event,
    validate_trace_seq,
)


class PostgresEventStore:
    """PostgreSQL implementation of EventStore protocol.

    This class provides persistent event storage using PostgreSQL.
    It implements the EventStore protocol per SSOT 11.6.

    Features:
    - Automatic schema migration on initialization
    - Idempotency enforcement via UNIQUE constraint
    - trace_seq monotonicity enforcement
    - TraceFinished locks traces
    - PII guard on payloads

    Usage:
        store = PostgresEventStore("host=localhost dbname=dg user=postgres")
    """

    SCHEMA_MIGRATIONS_TABLE = "schema_migrations"

    def __init__(self, conninfo: str) -> None:
        """Initialize PostgreSQL event store.

        Args:
            conninfo: PostgreSQL connection string
                     e.g., "host=localhost dbname=dg user=postgres password=secret"
        """
        self._conninfo = conninfo
        self._conn: Connection[Any] = psycopg.connect(conninfo, row_factory=dict_row)
        self._conn.autocommit = False

        # Run migrations
        self._migrate()

    def _get_migrations_dir(self) -> Path:
        """Get the migrations directory path."""
        return Path(__file__).parent / "migrations"

    def _ensure_schema_migrations_table(self) -> None:
        """Create schema_migrations table if it doesn't exist."""
        with self._conn.cursor() as cur:
            cur.execute(f"""
                CREATE TABLE IF NOT EXISTS {self.SCHEMA_MIGRATIONS_TABLE} (
                    version INTEGER PRIMARY KEY,
                    name TEXT NOT NULL,
                    applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                )
            """)
        self._conn.commit()

    def _get_applied_versions(self) -> set[int]:
        """Get set of already-applied migration versions."""
        with self._conn.cursor() as cur:
            cur.execute(f"SELECT version FROM {self.SCHEMA_MIGRATIONS_TABLE}")
            return {row["version"] for row in cur.fetchall()}

    def _discover_migrations(self) -> list[tuple[int, str, str]]:
        """Discover all migration files.

        Returns:
            List of (version, name, sql) tuples sorted by version
        """
        migrations: list[tuple[int, str, str]] = []
        pattern = re.compile(r"^(\d{4})_(.+)\.sql$")
        migrations_dir = self._get_migrations_dir()

        if not migrations_dir.exists():
            return migrations

        for path in sorted(migrations_dir.glob("*.sql")):
            match = pattern.match(path.name)
            if match:
                version = int(match.group(1))
                name = match.group(2)
                sql = path.read_text(encoding="utf-8")
                migrations.append((version, name, sql))

        return sorted(migrations, key=lambda m: m[0])

    def _apply_migration(self, version: int, name: str, sql: str) -> None:
        """Apply a single migration.

        Args:
            version: Migration version number
            name: Migration name
            sql: SQL to execute
        """
        with self._conn.cursor() as cur:
            # Execute migration SQL
            cur.execute(sql)

            # Record as applied
            cur.execute(
                f"""
                INSERT INTO {self.SCHEMA_MIGRATIONS_TABLE} (version, name)
                VALUES (%s, %s)
                """,
                (version, name),
            )
        self._conn.commit()

    def _migrate(self) -> None:
        """Apply pending database migrations."""
        self._ensure_schema_migrations_table()
        applied = self._get_applied_versions()
        all_migrations = self._discover_migrations()

        for version, name, sql in all_migrations:
            if version not in applied:
                self._apply_migration(version, name, sql)

    def close(self) -> None:
        """Close the database connection."""
        self._conn.close()

    def __enter__(self) -> "PostgresEventStore":
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
            with self._conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO dg_event_log (
                        event_id, trace_id, trace_seq, event_type,
                        occurred_at, recorded_at,
                        producer_id, system, subsystem,
                        actor_type, actor_id,
                        correlation_id, causation_event_id,
                        idempotency_key, schema_version,
                        payload_json, payload_hash, tags_json
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING log_seq
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
                result = cur.fetchone()
                if result is None:
                    raise DecisionGraphError(
                        DG_ERR_STORAGE, "Failed to get log_seq after insert"
                    )
                log_seq = result["log_seq"]

            self._conn.commit()

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

        except psycopg.errors.UniqueViolation as e:
            self._conn.rollback()
            error_str = str(e).lower()
            if "idempotency" in error_str:
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
        except psycopg.Error as e:
            self._conn.rollback()
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
        with self._conn.cursor() as cur:
            cur.execute(
                """
                SELECT * FROM dg_event_log
                WHERE producer_id = %s AND idempotency_key = %s
                """,
                (envelope.source.producer_id, envelope.idempotency_key),
            )
            row = cur.fetchone()

        if row is None:
            return None

        # Check if payload matches
        if row["payload_hash"] == payload_hash:
            # Idempotent retry - return existing event
            return row_to_stored_event(row)
        else:
            # Different payload - conflict
            raise DecisionGraphError(
                DG_ERR_IDEMPOTENCY_CONFLICT,
                f"Idempotency key '{envelope.idempotency_key}' already used "
                f"with different payload",
            )

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
        query = "SELECT * FROM dg_event_log WHERE trace_id = %s"
        params: list[Any] = [trace_id]

        if since_trace_seq is not None:
            query += " AND trace_seq > %s"
            params.append(since_trace_seq)

        query += " ORDER BY trace_seq ASC"

        if limit is not None:
            query += " LIMIT %s"
            params.append(limit)

        with self._conn.cursor() as cur:
            cur.execute(query, params)
            return [row_to_stored_event(row) for row in cur.fetchall()]

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
        query = "SELECT * FROM dg_event_log WHERE TRUE"
        params: list[Any] = []

        if since_log_seq is not None:
            query += " AND log_seq > %s"
            params.append(since_log_seq)
        if until_log_seq is not None:
            query += " AND log_seq <= %s"
            params.append(until_log_seq)
        if event_type is not None:
            query += " AND event_type = %s"
            params.append(event_type)
        if trace_id is not None:
            query += " AND trace_id = %s"
            params.append(trace_id)

        query += " ORDER BY log_seq ASC"

        if limit is not None:
            query += " LIMIT %s"
            params.append(limit)

        with self._conn.cursor() as cur:
            cur.execute(query, params)
            return [row_to_stored_event(row) for row in cur.fetchall()]

    def get_last_log_seq(self) -> int:
        """Get the current maximum log_seq.

        Returns:
            Maximum log_seq in the store, or 0 if empty
        """
        with self._conn.cursor() as cur:
            cur.execute("SELECT MAX(log_seq) as max_seq FROM dg_event_log")
            row = cur.fetchone()
            return row["max_seq"] if row and row["max_seq"] is not None else 0

    def is_trace_finished(self, trace_id: str) -> bool:
        """Check if a trace has been finished.

        Args:
            trace_id: Trace ID to check

        Returns:
            True if TraceFinished event exists for this trace
        """
        with self._conn.cursor() as cur:
            cur.execute(
                """
                SELECT 1 FROM dg_event_log
                WHERE trace_id = %s AND event_type = %s
                LIMIT 1
                """,
                (trace_id, EVENT_TYPE_TRACE_FINISHED),
            )
            return cur.fetchone() is not None

    def get_next_trace_seq(self, trace_id: str) -> int:
        """Get the next expected trace_seq for a trace.

        Args:
            trace_id: Trace ID to check

        Returns:
            Next expected trace_seq (max existing + 1, or 0 if no events)
        """
        with self._conn.cursor() as cur:
            cur.execute(
                "SELECT MAX(trace_seq) as max_seq FROM dg_event_log WHERE trace_id = %s",
                (trace_id,),
            )
            row = cur.fetchone()
            if row is None or row["max_seq"] is None:
                return 0
            return int(row["max_seq"]) + 1

    def clear(self) -> None:
        """Clear all stored events.

        Useful for test isolation.
        """
        with self._conn.cursor() as cur:
            cur.execute("TRUNCATE TABLE dg_event_log RESTART IDENTITY CASCADE")
        self._conn.commit()


__all__ = ["PostgresEventStore"]
