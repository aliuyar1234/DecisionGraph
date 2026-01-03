# Implementation Plan: PostgreSQL Storage Backend

**Branch**: `005-storage-postgres` | **Date**: 2026-01-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-storage-postgres/spec.md`
**SSOT Phase**: P4 — Postgres Backend + Parity Tests

## Summary

Implement the PostgreSQL storage backend for server deployments with semantic parity to SQLite. The Postgres backend MUST produce identical projection digests for the same event set.

## Technical Context

**Language/Version**: Python 3.12+ (DD-003)
**Primary Dependencies**: psycopg (optional extra)
**Storage**: PostgreSQL with raw SQL (DD-006)
**Testing**: pytest with Docker Postgres
**Target Platform**: Linux server deployments
**Project Type**: Single project with src-layout
**Performance Goals**: 10K appends in <10s, digest parity with SQLite
**Constraints**: Optional dependency, no ORM (DD-006)
**Scale/Scope**: Mirror SQLite schema and behavior

## Constitution Check

*GATE: All checks pass - no violations*

| Principle | Status | Verification |
|-----------|--------|--------------|
| I. Append-Only SSOT | ✅ | Same constraints as SQLite |
| II. Deterministic Replay | ✅ | Digest parity with SQLite |
| III. Library-First | ✅ | Optional extra, not required |
| IV. Minimal Dependencies | ✅ | Raw SQL, psycopg as optional |
| V. Module Boundaries | ✅ | storage.postgres hidden from query |
| VI. Framework-Agnostic | ✅ | No ORM, no framework deps |

## Project Structure

### Source Code

```text
src/decisiongraph/
  storage/
    postgres/
      __init__.py
      backend.py           # PostgresEventStore implementation
      migrations/
        0001_event_log.sql
        0002_projections.sql

tests/
  integration/
    test_postgres_backend.py
    test_parity.py         # SQLite vs Postgres comparison
```

## Implementation Steps

### Phase 1: Postgres Migrations

1. Create `migrations/0001_event_log.sql`:
   - Same schema as SQLite with Postgres syntax
   - `log_seq BIGSERIAL PRIMARY KEY`
   - Same constraints and indexes

2. Create `migrations/0002_projections.sql`:
   - Same projection tables as SQLite

### Phase 2: PostgresEventStore

1. Implement `backend.py`:
   - `PostgresEventStore` implementing `EventStore` protocol
   - Connection string configuration
   - Auto-migration on init
   - Same methods as SQLiteEventStore

### Phase 3: Parity Tests

1. Create `test_parity.py`:
   - Same events to both backends
   - Compare digests
   - Compare query results

### Phase 4: Optional Import

1. Conditional import in `storage/__init__.py`:
   ```python
   try:
       from .postgres import PostgresEventStore
   except ImportError:
       PostgresEventStore = None  # psycopg not installed
   ```

2. Update `pyproject.toml`:
   ```toml
   [project.optional-dependencies]
   postgres = ["psycopg>=3.0"]
   ```

### Phase 5: Tests

1. TC-P4-001 through TC-P4-010
2. Docker-based Postgres tests

## SSOT References

- Section 6.1.4: Storage Columns
- Section 8.1 P4: Phase definition
- DD-005: Backend decision
- DD-006: DB-API decision
