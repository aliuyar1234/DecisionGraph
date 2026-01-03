# Research: SQLite Storage Backend

**Date**: 2026-01-01
**Phase**: P2 — SQLite Backend + Migrations

## Overview

All technical decisions are frozen in SSOT. This document consolidates the relevant specifications.

## Database Schema (SSOT 6.1.4)

### dg_event_log Table

```sql
CREATE TABLE dg_event_log (
    log_seq INTEGER PRIMARY KEY,
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

CREATE INDEX idx_event_type ON dg_event_log(event_type);
CREATE INDEX idx_trace_id ON dg_event_log(trace_id);
CREATE INDEX idx_correlation_id ON dg_event_log(correlation_id);
```

### Key Design Decisions

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| log_seq | INTEGER PRIMARY KEY | Auto-increment in SQLite |
| Timestamps | TEXT (RFC3339) | SQLite has no native datetime |
| Payload | TEXT (JSON) | Canonical JSON stored |
| Idempotency | UNIQUE constraint | Database-enforced |
| trace_seq | UNIQUE per trace | Database-enforced |

## Migration Engine (DD-015)

### Requirements

1. Numbered `.sql` files: `0001_name.sql`, `0002_name.sql`, etc.
2. `schema_migrations` tracking table
3. Apply in numerical order
4. Each migration in transaction
5. Idempotent (skip already-applied)

### schema_migrations Table

```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL
);
```

### Migration Discovery

```python
def discover_migrations(path: Path) -> list[tuple[int, Path]]:
    """Find migration files sorted by version number."""
    pattern = r"^(\d{4})_.*\.sql$"
    # Return [(1, path_0001), (2, path_0002), ...]
```

## Append-Only Enforcement

SQLite doesn't have triggers to prevent UPDATE/DELETE, but:

1. **Application layer**: Only call INSERT
2. **No UPDATE/DELETE methods** in SQLiteEventStore
3. **Integration tests**: Verify no mutations possible through API

## Idempotency Handling

```sql
-- Check for existing
SELECT * FROM dg_event_log
WHERE producer_id = ? AND idempotency_key = ?;

-- If exists, verify payload matches
-- If matches, return existing StoredEvent
-- If differs, raise DG_ERR_IDEMPOTENCY_CONFLICT

-- If not exists, insert
INSERT INTO dg_event_log (...) VALUES (...);
```

## trace_seq Validation

Before insert, verify:

```sql
-- Get max trace_seq for this trace
SELECT MAX(trace_seq) FROM dg_event_log WHERE trace_id = ?;

-- If TraceFinished exists, reject
SELECT 1 FROM dg_event_log
WHERE trace_id = ? AND event_type = 'TraceFinished';
```

## Connection Management

```python
class SQLiteEventStore:
    def __init__(self, db_path: str | Path):
        self._conn = sqlite3.connect(
            db_path,
            isolation_level=None,  # Autocommit
            check_same_thread=False
        )
        self._conn.row_factory = sqlite3.Row
        self._run_migrations()
```

## Performance Considerations

1. **WAL mode**: Enable for concurrent reads
   ```sql
   PRAGMA journal_mode=WAL;
   ```

2. **Synchronous**: Balance durability vs speed
   ```sql
   PRAGMA synchronous=NORMAL;
   ```

3. **Foreign keys**: Not needed (no FK relationships)

## Projection Tables (0002_projections.sql)

Reserved for Phase 3, but schema created here for forward compatibility.

```sql
CREATE TABLE dg_cg_nodes (...);
CREATE TABLE dg_cg_edges (...);
CREATE TABLE dg_trace_summary (...);
CREATE TABLE dg_precedent_index (...);
CREATE TABLE dg_projection_meta (...);
```

## Conclusion

All technical details are specified in SSOT. No external research required.
