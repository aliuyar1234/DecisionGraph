# Data Model: PostgreSQL Storage Backend

**Date**: 2026-01-01
**Phase**: P4 — Postgres Backend + Parity Tests
**SSOT Reference**: Section 6.1.4

## Schema (Postgres Syntax)

### dg_event_log

```sql
CREATE TABLE dg_event_log (
    log_seq BIGSERIAL PRIMARY KEY,
    event_id TEXT UNIQUE NOT NULL,
    trace_id TEXT NOT NULL,
    trace_seq INTEGER NOT NULL,
    event_type TEXT NOT NULL,
    occurred_at TEXT NOT NULL,
    recorded_at TEXT NOT NULL,
    producer_id TEXT NOT NULL,
    system TEXT NOT NULL,
    subsystem TEXT,
    actor_type TEXT NOT NULL,
    actor_id TEXT NOT NULL,
    correlation_id TEXT,
    causation_event_id TEXT,
    idempotency_key TEXT NOT NULL,
    schema_version INTEGER NOT NULL,
    payload_json TEXT NOT NULL,
    payload_hash TEXT NOT NULL,
    tags_json TEXT NOT NULL,

    UNIQUE (trace_id, trace_seq),
    UNIQUE (producer_id, idempotency_key)
);
```

### Projection Tables

Same as SQLite (see 003-storage-sqlite/data-model.md).

## PostgresEventStore

```python
class PostgresEventStore:
    """PostgreSQL implementation of EventStore protocol."""

    def __init__(self, conninfo: str):
        """
        Initialize with connection string.

        Args:
            conninfo: PostgreSQL connection string
                      e.g., "host=localhost dbname=dg user=postgres"
        """
        ...

    def append_event(self, envelope: EventEnvelope) -> StoredEvent:
        """Append event, return stored event with log_seq."""
        ...

    def get_trace_events(
        self,
        trace_id: str,
        since_trace_seq: int | None = None,
        limit: int | None = None
    ) -> list[StoredEvent]:
        """Get events for trace, ordered by trace_seq."""
        ...

    def list_events(
        self,
        since_log_seq: int | None = None,
        until_log_seq: int | None = None,
        event_type: str | None = None,
        limit: int | None = None
    ) -> list[StoredEvent]:
        """List events, ordered by log_seq."""
        ...

    def get_last_log_seq(self) -> int:
        """Get current max log_seq."""
        ...
```

## Parity Requirements

| Aspect | Requirement |
|--------|-------------|
| Schema | Semantically identical (syntax may differ) |
| Constraints | Same UNIQUE and NOT NULL constraints |
| Ordering | Same log_seq and trace_seq ordering |
| Digests | Byte-identical for same events |
| Errors | Same error codes for same conditions |

## Optional Dependency

```python
# In storage/__init__.py
try:
    from .postgres import PostgresEventStore
    HAS_POSTGRES = True
except ImportError:
    PostgresEventStore = None
    HAS_POSTGRES = False
```

Usage:
```python
from decisiongraph.storage import PostgresEventStore

if PostgresEventStore is None:
    raise ImportError("Install decisiongraph[postgres] for Postgres support")
```
