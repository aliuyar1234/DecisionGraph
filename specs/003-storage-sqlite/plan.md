# Implementation Plan: SQLite Storage Backend

**Branch**: `003-storage-sqlite` | **Date**: 2026-01-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-storage-sqlite/spec.md`
**SSOT Phase**: P2 — SQLite Backend + Migrations

## Summary

Implement the SQLite storage backend with schema creation, migrations, append-only constraints, and idempotency enforcement via database indexes. SQLite serves as the embedded backend for development and single-node deployments.

## Technical Context

**Language/Version**: Python 3.12+ (DD-003)
**Primary Dependencies**: sqlite3 (stdlib)
**Storage**: SQLite with raw SQL (DD-006)
**Testing**: pytest with temp files
**Target Platform**: Cross-platform (SQLite3 embedded)
**Project Type**: Single project with src-layout
**Performance Goals**: 1000 appends in <5s, query in <50ms
**Constraints**: No ORM (DD-006), numbered SQL migrations (DD-015)
**Scale/Scope**: Event log + projection tables

## Constitution Check

*GATE: All checks pass - no violations*

| Principle | Status | Verification |
|-----------|--------|--------------|
| I. Append-Only SSOT | ✅ | No UPDATE/DELETE on dg_event_log |
| II. Deterministic Replay | ✅ | log_seq ordering enables replay |
| III. Library-First | ✅ | SQLite embedded, no server needed |
| IV. Minimal Dependencies | ✅ | Raw SQL via DB-API (DD-006) |
| V. Module Boundaries | ✅ | storage.sqlite hidden from query layer |
| VI. Framework-Agnostic | ✅ | No ORM, no framework deps |

## Project Structure

### Documentation (this feature)

```text
specs/003-storage-sqlite/
├── spec.md
├── plan.md              # This file
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
└── checklists/
```

### Source Code (repository root)

```text
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

**Structure Decision**: Extends 001/002 structure per SSOT 5.2

## Implementation Steps

### Phase 1: Migration Engine

1. Create `storage/migrations.py`:
   - `MigrationEngine` class
   - Numbered `.sql` file discovery
   - `schema_migrations` tracking table
   - Atomic transaction per migration

### Phase 2: Event Log Schema

1. Create `migrations/0001_event_log.sql`:
   - `dg_event_log` table per SSOT 6.1.4
   - `log_seq` as INTEGER PRIMARY KEY
   - UNIQUE on `(trace_id, trace_seq)`
   - UNIQUE on `(producer_id, idempotency_key)`
   - Indexes on `event_type`, `correlation_id`

### Phase 3: SQLiteEventStore

1. Implement `storage/sqlite/backend.py`:
   - `SQLiteEventStore` class implementing `EventStore` protocol
   - Auto-migration on init
   - `append_event()` with idempotency check
   - `get_trace_events()` with trace_seq order
   - `list_events()` with log_seq order
   - `get_last_log_seq()`

### Phase 4: Constraint Enforcement

1. Verify via tests:
   - Idempotency via UNIQUE constraint
   - trace_seq uniqueness
   - TraceFinished locks trace

### Phase 5: Projection Tables Schema

1. Create `migrations/0002_projections.sql`:
   - `dg_cg_nodes` table
   - `dg_cg_edges` table
   - `dg_trace_summary` table
   - `dg_precedent_index` table
   - `dg_projection_meta` table

### Phase 6: Tests

1. TC-P2-001 through TC-P2-010
2. Integration tests with temp database

## SSOT References

- Section 6.1.4: Storage Columns
- Section 8.1 P2: Phase definition
- DD-005: SQLite + Postgres decision
- DD-006: Raw SQL decision
- DD-015: Migration engine decision
