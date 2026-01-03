# API Contract: SQLite Schema

**SSOT Reference**: Section 6.1.4

## Migration 0001: Event Log

```sql
-- 0001_event_log.sql

CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL
);

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

## Migration 0002: Projections

```sql
-- 0002_projections.sql

CREATE TABLE dg_cg_nodes (
    node_key TEXT PRIMARY KEY,
    node_type TEXT NOT NULL,
    node_id TEXT NOT NULL,
    projection_version INTEGER NOT NULL DEFAULT 1,
    created_at_log_seq INTEGER NOT NULL,
    attrs_json TEXT NOT NULL DEFAULT '{}'
);

CREATE TABLE dg_cg_edges (
    edge_key TEXT PRIMARY KEY,
    edge_type TEXT NOT NULL,
    from_node_key TEXT NOT NULL,
    to_node_key TEXT NOT NULL,
    source_event_id TEXT NOT NULL,
    projection_version INTEGER NOT NULL DEFAULT 1,
    created_at_log_seq INTEGER NOT NULL,
    attrs_json TEXT NOT NULL DEFAULT '{}'
);

CREATE INDEX idx_edges_from ON dg_cg_edges(from_node_key);
CREATE INDEX idx_edges_to ON dg_cg_edges(to_node_key);
CREATE INDEX idx_edges_type ON dg_cg_edges(edge_type);

CREATE TABLE dg_trace_summary (
    trace_id TEXT PRIMARY KEY,
    workflow TEXT NOT NULL,
    title TEXT NOT NULL,
    primary_entity_type TEXT NOT NULL,
    primary_entity_id TEXT NOT NULL,
    started_at TEXT NOT NULL,
    finished_at TEXT,
    outcome TEXT,
    started_log_seq INTEGER NOT NULL,
    finished_log_seq INTEGER
);

CREATE TABLE dg_precedent_index (
    id INTEGER PRIMARY KEY,
    trace_id TEXT NOT NULL,
    policy_id TEXT,
    policy_version TEXT,
    exception_id TEXT,
    outcome TEXT NOT NULL,
    finished_log_seq INTEGER NOT NULL
);

CREATE INDEX idx_precedent_policy ON dg_precedent_index(policy_id);
CREATE INDEX idx_precedent_trace ON dg_precedent_index(trace_id);

CREATE TABLE dg_projection_meta (
    projection_name TEXT PRIMARY KEY,
    projection_version INTEGER NOT NULL,
    last_applied_log_seq INTEGER NOT NULL,
    updated_at TEXT NOT NULL
);
```

## Column Semantics

### log_seq

- Type: INTEGER PRIMARY KEY (auto-increment in SQLite)
- Assigned at INSERT time by database
- Monotonically increasing
- Used for global event ordering

### Timestamps

All timestamps stored as TEXT in RFC3339 format:
- `2025-12-31T10:00:00Z`
- Always UTC (Z suffix)

### JSON Columns

- `payload_json`: Canonical JSON (sorted keys, no whitespace)
- `tags_json`: Object of string key-value pairs
- `attrs_json`: Always `{}` in v1

### Idempotency

Enforced by UNIQUE constraint on `(producer_id, idempotency_key)`.

On conflict:
1. Check if existing payload matches
2. If match: return existing StoredEvent (idempotent success)
3. If different: raise `DG_ERR_IDEMPOTENCY_CONFLICT`

### trace_seq

Enforced by UNIQUE constraint on `(trace_id, trace_seq)`.

Validation before insert:
1. If trace_seq=0: Must be TraceStarted
2. If trace_seq>0: Must have trace_seq-1 already stored
3. If TraceFinished exists: Reject all new events
