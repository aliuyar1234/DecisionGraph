# Feature Specification: SQLite Storage Backend

**Feature Branch**: `003-storage-sqlite`
**Created**: 2026-01-01
**Status**: Draft
**SSOT Phase**: P2 — SQLite Backend + Migrations
**SSOT Reference**: `SPEC_v1.0.3-minpatch.md` Section 8.1 (P2)

## Overview

This specification covers the SQLite storage backend implementation: schema creation, migrations, append-only constraints, and idempotency enforcement via database indexes. SQLite serves as the embedded backend for development and single-node deployments.

**SSOT Principle**: Storage schema and constraints are defined in SSOT Section 6.1.4. This spec references those sections.

---

## Constitution Check

| Principle | Applies | How Verified |
|-----------|---------|--------------|
| I. Append-Only SSOT | ✅ | No UPDATE/DELETE on dg_event_log |
| II. Deterministic Replay | ✅ | log_seq ordering enables replay |
| III. Library-First | ✅ | SQLite embedded, no server needed |
| IV. Minimal Dependencies | ✅ | Raw SQL via DB-API (DD-006) |
| V. Module Boundaries | ✅ | storage.sqlite hidden from query layer |
| VI. Framework-Agnostic | ✅ | No ORM, no framework deps |

**Key Constraints**:
- Storage MUST use raw SQL, NOT SQLAlchemy (Constitution IV, DD-006)
- Append-only enforced via DB constraints (Constitution I)
- Migrations use numbered .sql files, NOT Alembic (Constitution IV, DD-015)
- No UI or service layer in storage module (Constitution III)

---

## User Scenarios & Testing

### User Story 1 - Database Initialization (Priority: P1)

As a developer, I want automatic database initialization so that I can use DecisionGraph without manual setup.

**Why this priority**: First-run experience must be seamless.

**Independent Test**: Can be verified by creating a SQLiteEventStore and checking that tables exist.

**Acceptance Scenarios**:

1. **Given** a new database file path, **When** I create SQLiteEventStore, **Then** migrations are applied automatically
2. **Given** an existing database with older schema, **When** I create SQLiteEventStore, **Then** pending migrations are applied
3. **Given** a database at current schema version, **When** I create SQLiteEventStore, **Then** no migrations run

---

### User Story 2 - Persistent Event Storage (Priority: P1)

As a system operator, I want events persisted to disk so that data survives restarts.

**Why this priority**: Durability is core to system-of-record functionality.

**Independent Test**: Can be verified by appending events, closing connection, reopening, and retrieving events.

**Acceptance Scenarios**:

1. **Given** I append events to SQLite, **When** I close and reopen the database, **Then** all events are retrievable
2. **Given** events are stored, **When** I query by trace_id, **Then** events are returned in trace_seq order
3. **Given** events are stored, **When** I call `get_last_log_seq()`, **Then** correct max log_seq is returned

---

### User Story 3 - Constraint Enforcement (Priority: P1)

As a data integrity guardian, I want database constraints so that invariants cannot be violated.

**Why this priority**: Append-only and uniqueness must be enforced at storage level.

**Independent Test**: Can be verified by attempting to insert duplicate idempotency keys.

**Acceptance Scenarios**:

1. **Given** an event with idempotency_key "X", **When** I try to insert another with same producer_id + key, **Then** database constraint prevents it
2. **Given** a trace with event at trace_seq=1, **When** I try to insert another at trace_seq=1, **Then** UNIQUE constraint prevents it
3. **Given** `log_seq` column, **When** events are inserted, **Then** `log_seq` is monotonically increasing

---

### User Story 4 - Transactional Appends (Priority: P1)

As a reliability engineer, I want atomic transactions so that partial writes don't corrupt the log.

**Why this priority**: Append-only integrity requires atomic commits.

**Independent Test**: Can be verified by simulating failure mid-transaction.

**Acceptance Scenarios**:

1. **Given** I start appending an event, **When** transaction commits, **Then** event is visible
2. **Given** I start appending an event, **When** transaction rolls back, **Then** event is not visible
3. **Given** multiple concurrent appends, **When** all commit, **Then** each has unique log_seq

---

### User Story 5 - Query Performance (Priority: P2)

As a developer, I want indexed queries so that lookups are efficient.

**Why this priority**: Query performance affects decision-time retrieval.

**Independent Test**: Can be verified by EXPLAIN query plan showing index usage.

**Acceptance Scenarios**:

1. **Given** query by trace_id, **When** executed, **Then** index on trace_id is used
2. **Given** query by correlation_id, **When** executed, **Then** index on correlation_id is used
3. **Given** query by event_type, **When** executed, **Then** index on event_type is used

---

### Edge Cases

- What happens when disk is full? → `DG_ERR_STORAGE` with clear message
- What happens when database file is locked? → Retry with timeout, then error
- What happens when migration fails mid-way? → Transaction rollback, no partial state
- What happens when SQLite version is too old? → Check version at startup

---

## Requirements

### Functional Requirements

- **FR-001**: Schema MUST match → SSOT 6.1.4
- **FR-002**: `log_seq` MUST be INTEGER PRIMARY KEY (auto-increment) → SSOT 6.1.4
- **FR-003**: UNIQUE constraint on `(trace_id, trace_seq)` → SSOT 6.1.4
- **FR-004**: UNIQUE constraint on `(producer_id, idempotency_key)` → SSOT 6.1.4
- **FR-005**: Index on `event_type` → SSOT 6.1.4
- **FR-006**: Index on `correlation_id` → SSOT 6.1.4
- **FR-007**: Migrations MUST use numbered `.sql` files → SSOT DD-015
- **FR-008**: `schema_migrations` table MUST track applied migrations → SSOT DD-015
- **FR-009**: Canonical JSON stored in `payload_json` column → SSOT 6.1.4
- **FR-010**: `payload_hash` verified on read (optional but recommended)

### Key Entities

- **SQLiteEventStore**: Implements EventStore protocol for SQLite
- **MigrationEngine**: Applies numbered SQL migrations
- **dg_event_log**: Main event table (SSOT 6.1.4)

### Table Schema (from SSOT 6.1.4)

```
dg_event_log:
  - log_seq INTEGER PRIMARY KEY
  - event_id TEXT UNIQUE NOT NULL
  - trace_id TEXT NOT NULL
  - trace_seq INTEGER NOT NULL
  - event_type TEXT NOT NULL
  - occurred_at TEXT NOT NULL
  - recorded_at TEXT NOT NULL
  - producer_id TEXT NOT NULL
  - system TEXT NOT NULL
  - subsystem TEXT NULL
  - actor_type TEXT NOT NULL
  - actor_id TEXT NOT NULL
  - correlation_id TEXT NULL
  - causation_event_id TEXT NULL
  - idempotency_key TEXT NOT NULL
  - schema_version INTEGER NOT NULL
  - payload_json TEXT NOT NULL
  - payload_hash TEXT NOT NULL
  - tags_json TEXT NOT NULL
```

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: Fresh database initialization completes in under 1 second
- **SC-002**: 1000 event appends complete in under 5 seconds
- **SC-003**: Query by trace_id returns results in under 50ms for 10K events
- **SC-004**: All 10 test cases from SSOT P2 pass (TC-P2-001 through TC-P2-010)
- **SC-005**: Database survives restart with all data intact

### Test Cases (from SSOT 8.1)

| ID | Name | Description |
|----|------|-------------|
| TC-P2-001 | sqlite_migrate_fresh_db | Migrations apply to fresh database |
| TC-P2-002 | sqlite_append_persists | Events survive connection close |
| TC-P2-003 | sqlite_idempotency_unique | Idempotency constraint works |
| TC-P2-004 | sqlite_trace_seq_unique | trace_seq uniqueness enforced |
| TC-P2-005 | sqlite_trace_events_order | Events ordered by trace_seq |
| TC-P2-006 | sqlite_list_events_order | Events ordered by log_seq |
| TC-P2-007 | sqlite_payload_hash_verified | Hash matches on read |
| TC-P2-008 | sqlite_finish_locks | TraceFinished prevents appends |
| TC-P2-009 | sqlite_restart_preserves_seq | log_seq continues after restart |
| TC-P2-010 | sqlite_reject_invalid_payload | Invalid payloads rejected |

---

## Dependencies & Constraints

### Depends On

- **001-foundation**: Error types, domain types
- **002-event-model**: EventStore protocol, EventEnvelope, StoredEvent

### Blocks

- 004-projections (P3)
- All subsequent phases

### Frozen Decisions

- **DD-005**: SQLite for embedded, Postgres for server
- **DD-006**: Raw SQL via DB-API (no ORM)
- **DD-015**: Own migration engine with numbered .sql files

---

## Files to Implement

```
src/decisiongraph/
  storage/
    sqlite/
      __init__.py
      backend.py           # SQLiteEventStore implementation
      migrations/
        0001_event_log.sql
        0002_projections.sql
    migrations.py          # MigrationEngine
tests/
  integration/
    test_sqlite_backend.py
```

---

## SSOT References

- Section 6.1.4: Storage Columns
- Section 8.1 P2: Phase definition and test cases
- DD-005: SQLite + Postgres decision
- DD-006: Raw SQL decision
- DD-015: Migration engine decision
