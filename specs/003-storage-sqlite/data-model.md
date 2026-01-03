# Data Model: SQLite Storage Backend

**Date**: 2026-01-01
**Phase**: P2 — SQLite Backend + Migrations
**SSOT Reference**: Section 6.1.4

## Tables

### dg_event_log

Primary event storage table.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| log_seq | INTEGER | PRIMARY KEY | Global ordering |
| event_id | TEXT | UNIQUE NOT NULL | UUID |
| trace_id | TEXT | NOT NULL | UUID |
| trace_seq | INTEGER | NOT NULL | Position in trace |
| event_type | TEXT | NOT NULL | One of 10 types |
| occurred_at | TEXT | NOT NULL | RFC3339 UTC |
| recorded_at | TEXT | NOT NULL | RFC3339 UTC |
| producer_id | TEXT | NOT NULL | Event source |
| system | TEXT | NOT NULL | System category |
| subsystem | TEXT | NULL | Optional subsystem |
| actor_type | TEXT | NOT NULL | agent/person/role/system |
| actor_id | TEXT | NOT NULL | Actor identifier |
| correlation_id | TEXT | NULL | Optional correlation |
| causation_event_id | TEXT | NULL | Optional causation |
| idempotency_key | TEXT | NOT NULL | Idempotency key |
| schema_version | INTEGER | NOT NULL | Always 1 |
| payload_json | TEXT | NOT NULL | Canonical JSON |
| payload_hash | TEXT | NOT NULL | sha256:... |
| tags_json | TEXT | NOT NULL | {} if empty |

**Constraints**:
- `UNIQUE (trace_id, trace_seq)` - One event per position
- `UNIQUE (producer_id, idempotency_key)` - Idempotency

**Indexes**:
- `idx_event_type(event_type)`
- `idx_trace_id(trace_id)`
- `idx_correlation_id(correlation_id)`

### schema_migrations

Migration tracking table.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| version | INTEGER | PRIMARY KEY | Migration number |
| applied_at | TEXT | NOT NULL | RFC3339 timestamp |

### dg_cg_nodes (Projection - Phase 3)

Context graph nodes.

| Column | Type | Constraints |
|--------|------|-------------|
| node_key | TEXT | PRIMARY KEY |
| node_type | TEXT | NOT NULL |
| node_id | TEXT | NOT NULL |
| projection_version | INTEGER | NOT NULL |
| created_at_log_seq | INTEGER | NOT NULL |
| attrs_json | TEXT | NOT NULL |

### dg_cg_edges (Projection - Phase 3)

Context graph edges.

| Column | Type | Constraints |
|--------|------|-------------|
| edge_key | TEXT | PRIMARY KEY |
| edge_type | TEXT | NOT NULL |
| from_node_key | TEXT | NOT NULL |
| to_node_key | TEXT | NOT NULL |
| source_event_id | TEXT | NOT NULL |
| projection_version | INTEGER | NOT NULL |
| created_at_log_seq | INTEGER | NOT NULL |
| attrs_json | TEXT | NOT NULL |

### dg_trace_summary (Projection - Phase 3)

Trace metadata for explorer/search.

| Column | Type | Constraints |
|--------|------|-------------|
| trace_id | TEXT | PRIMARY KEY |
| workflow | TEXT | NOT NULL |
| title | TEXT | NOT NULL |
| primary_entity_type | TEXT | NOT NULL |
| primary_entity_id | TEXT | NOT NULL |
| started_at | TEXT | NOT NULL |
| finished_at | TEXT | NULL |
| outcome | TEXT | NULL |
| started_log_seq | INTEGER | NOT NULL |
| finished_log_seq | INTEGER | NULL |

### dg_precedent_index (Projection - Phase 3)

Fast precedent lookup.

| Column | Type | Constraints |
|--------|------|-------------|
| id | INTEGER | PRIMARY KEY |
| trace_id | TEXT | NOT NULL |
| policy_id | TEXT | NULL |
| policy_version | TEXT | NULL |
| exception_id | TEXT | NULL |
| outcome | TEXT | NOT NULL |
| finished_log_seq | INTEGER | NOT NULL |

### dg_projection_meta (Projection - Phase 3)

Projection cursor tracking.

| Column | Type | Constraints |
|--------|------|-------------|
| projection_name | TEXT | PRIMARY KEY |
| projection_version | INTEGER | NOT NULL |
| last_applied_log_seq | INTEGER | NOT NULL |
| updated_at | TEXT | NOT NULL |

## Entity Relationships

```
dg_event_log (append-only)
    │
    │ log_seq ordering
    ▼
dg_projection_meta
    │ last_applied_log_seq
    ▼
┌─────────────┬─────────────┐
│             │             │
▼             ▼             ▼
dg_cg_nodes   dg_cg_edges   dg_trace_summary
    │             │             │
    │             │             ▼
    └─────────────┴────────► dg_precedent_index
```

## SQLiteEventStore Class

```python
class SQLiteEventStore:
    def __init__(self, db_path: str | Path): ...

    # EventStore protocol
    def append_event(self, envelope: EventEnvelope) -> StoredEvent: ...
    def get_trace_events(
        self,
        trace_id: str,
        since_trace_seq: int | None = None,
        limit: int | None = None
    ) -> list[StoredEvent]: ...
    def list_events(
        self,
        since_log_seq: int | None = None,
        until_log_seq: int | None = None,
        event_type: str | None = None,
        limit: int | None = None
    ) -> list[StoredEvent]: ...
    def get_last_log_seq(self) -> int: ...

    # Internal
    def _run_migrations(self) -> None: ...
    def _check_idempotency(self, producer_id: str, key: str) -> StoredEvent | None: ...
    def _check_trace_finished(self, trace_id: str) -> bool: ...
```
