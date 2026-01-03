# API Contract: PostgreSQL Schema

**SSOT Reference**: Section 6.1.4

## Schema (Postgres Syntax)

```sql
-- 0001_event_log.sql

CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL
);

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

CREATE INDEX idx_event_type ON dg_event_log(event_type);
CREATE INDEX idx_trace_id ON dg_event_log(trace_id);
CREATE INDEX idx_correlation_id ON dg_event_log(correlation_id);
```

```sql
-- 0002_projections.sql
-- Same as SQLite version (see 003-storage-sqlite/contracts/sqlite-schema.md)
```

## Differences from SQLite

| Aspect | SQLite | PostgreSQL |
|--------|--------|------------|
| Auto-increment | `INTEGER PRIMARY KEY` | `BIGSERIAL PRIMARY KEY` |
| Text | `TEXT` | `TEXT` |
| Integer | `INTEGER` | `INTEGER` |
| Boolean | `INTEGER` (0/1) | Could use `BOOLEAN`, but use `TEXT` for parity |
| JSON | `TEXT` | Could use `JSONB`, but use `TEXT` for parity |

## Parity Contract

For digest compatibility, we use `TEXT` for all string/JSON columns rather than Postgres-specific types (JSONB, etc.).

## Connection Requirements

- PostgreSQL 13+
- psycopg 3.0+
- Connection via psycopg.connect()
