# Research: PostgreSQL Storage Backend

**Date**: 2026-01-01
**Phase**: P4 — Postgres Backend + Parity Tests

## Overview

All technical decisions are frozen in SSOT. Postgres backend mirrors SQLite with syntax adaptations.

## Schema Differences (SQLite vs Postgres)

| Aspect | SQLite | Postgres |
|--------|--------|----------|
| Auto-increment | INTEGER PRIMARY KEY | BIGSERIAL PRIMARY KEY |
| Boolean | INTEGER (0/1) | BOOLEAN |
| Timestamps | TEXT | TEXT (same, for consistency) |
| JSON | TEXT | TEXT (could use JSONB, but TEXT for parity) |

## Postgres Schema

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

## Connection Management

```python
import psycopg

class PostgresEventStore:
    def __init__(self, conninfo: str):
        self._conn = psycopg.connect(conninfo)
        self._run_migrations()

    def _run_migrations(self):
        # Same logic as SQLite
        pass
```

## psycopg 3 (Recommended)

Use psycopg 3 (not psycopg2):
- Modern async-ready API
- Better type handling
- Active development

```toml
[project.optional-dependencies]
postgres = ["psycopg>=3.0"]
```

## Parity Testing Strategy

1. **Event Insertion**:
   - Insert identical events to both backends
   - Verify same StoredEvent returned (except log_seq timing)

2. **Query Results**:
   - `get_trace_events()` returns same order
   - `list_events()` returns same order

3. **Digest Parity**:
   - Run projector on both backends
   - Compare `compute_digest()` output
   - MUST be byte-identical

## CI Integration

```yaml
# GitHub Actions
services:
  postgres:
    image: postgres:15
    env:
      POSTGRES_PASSWORD: test
    ports:
      - 5432:5432
```

## Error Mapping

| Postgres Error | DecisionGraph Error |
|----------------|---------------------|
| UniqueViolation (23505) | DG_ERR_IDEMPOTENCY_CONFLICT |
| ConnectionError | DG_ERR_STORAGE |
| OperationalError | DG_ERR_STORAGE |

## Conclusion

Schema is identical to SQLite with minor syntax changes. Parity tests are critical.
