# Feature Specification: PostgreSQL Storage Backend

**Feature Branch**: `005-storage-postgres`
**Created**: 2026-01-01
**Status**: Draft
**SSOT Phase**: P4 — Postgres Backend + Parity Tests
**SSOT Reference**: `SPEC_v1.0.3-minpatch.md` Section 8.1 (P4)

## Overview

This specification covers the PostgreSQL storage backend for server deployments. The Postgres backend MUST have semantic parity with SQLite, including identical projection digests for the same event set.

**SSOT Principle**: Storage semantics are defined in SSOT Section 6.1.4. This backend implements the same schema with Postgres-specific syntax.

---

## Constitution Check

| Principle | Applies | How Verified |
|-----------|---------|--------------|
| I. Append-Only SSOT | ✅ | Same constraints as SQLite |
| II. Deterministic Replay | ✅ | Digest parity with SQLite |
| III. Library-First | ✅ | Optional extra, not required |
| IV. Minimal Dependencies | ✅ | Raw SQL, psycopg as optional |
| V. Module Boundaries | ✅ | storage.postgres hidden from query |
| VI. Framework-Agnostic | ✅ | No ORM, no framework deps |

**Key Constraints**:
- Postgres MUST be optional extra `[postgres]` (Constitution IV, DD-005)
- Storage MUST use raw SQL, NOT SQLAlchemy (Constitution IV, DD-006)
- Digest MUST match SQLite for identical events (Constitution II)
- Same append-only constraints as SQLite (Constitution I)

---

## User Scenarios & Testing

### User Story 1 - Server-Grade Storage (Priority: P1)

As an enterprise operator, I want PostgreSQL support so that I can deploy DecisionGraph in a server environment.

**Why this priority**: Enterprise deployments require Postgres for reliability and scale.

**Independent Test**: Can be verified by running the same test suite against Postgres.

**Acceptance Scenarios**:

1. **Given** a Postgres connection string, **When** I create PostgresEventStore, **Then** migrations are applied
2. **Given** events in Postgres, **When** I query, **Then** results match SQLite behavior
3. **Given** Postgres backend, **When** I run projector, **Then** digest matches SQLite for same events

---

### User Story 2 - Backend Parity (Priority: P1)

As a developer, I want SQLite and Postgres to behave identically so that tests transfer between environments.

**Why this priority**: Parity ensures development (SQLite) matches production (Postgres).

**Independent Test**: Can be verified by running parity tests with identical fixtures.

**Acceptance Scenarios**:

1. **Given** same events, **When** stored in SQLite and Postgres, **Then** `get_trace_events()` returns identical results
2. **Given** same events, **When** projections built, **Then** digests are byte-identical
3. **Given** idempotency scenario, **When** tested on both backends, **Then** behavior is identical

---

### User Story 3 - Optional Dependency (Priority: P2)

As a library user, I want Postgres as an optional dependency so that I can use DecisionGraph without installing psycopg.

**Why this priority**: Minimal dependencies for embedded usage.

**Independent Test**: Can be verified by importing `decisiongraph` without psycopg installed.

**Acceptance Scenarios**:

1. **Given** I install `decisiongraph` without extras, **Then** Postgres backend is not available
2. **Given** I install `decisiongraph[postgres]`, **Then** PostgresEventStore is importable
3. **Given** Postgres is not installed, **When** I try to use PostgresEventStore, **Then** clear import error

---

### Edge Cases

- What happens when connection drops mid-transaction? → Retry with new connection
- What happens when Postgres version is too old? → Check version at startup
- What happens when schema drift occurs? → Migration system handles it

---

## Requirements

### Functional Requirements

- **FR-001**: Schema MUST match SQLite semantically → SSOT 6.1.4
- **FR-002**: `log_seq` MUST be BIGSERIAL PRIMARY KEY → SSOT DD-007
- **FR-003**: All constraints from SQLite MUST be replicated
- **FR-004**: Projector MUST run identically on Postgres
- **FR-005**: Digest MUST match SQLite for identical events → SSOT 6.2.7
- **FR-006**: `decisiongraph[postgres]` MUST be optional extra → SSOT DD-005
- **FR-007**: Connection management MUST handle timeouts gracefully

### Key Entities

- **PostgresEventStore**: Implements EventStore protocol for Postgres
- **dg_event_log**: Event table (BIGSERIAL for log_seq)
- **Projection tables**: Same as SQLite

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: All SQLite integration tests pass on Postgres
- **SC-002**: Digest parity verified for golden fixture
- **SC-003**: 10K event append completes in under 10 seconds
- **SC-004**: All 10 test cases from SSOT P4 pass (TC-P4-001 through TC-P4-010)
- **SC-005**: Optional dependency import works correctly

### Test Cases (from SSOT 8.1)

| ID | Name | Description |
|----|------|-------------|
| TC-P4-001 | pg_migrate_fresh_db | Migrations apply cleanly |
| TC-P4-002 | pg_append_persists | Events persist correctly |
| TC-P4-003 | pg_idempotency_unique | Idempotency constraint works |
| TC-P4-004 | pg_trace_seq_unique | trace_seq uniqueness enforced |
| TC-P4-005 | pg_projector_runs | Projector works on Postgres |
| TC-P4-006 | pg_digest_matches_sqlite | Digest parity verified |
| TC-P4-007 | pg_list_events_order | Events ordered by log_seq |
| TC-P4-008 | pg_finish_locks | TraceFinished prevents appends |
| TC-P4-009 | pg_error_mapping_storage | Errors map to DG_ERR_STORAGE |
| TC-P4-010 | pg_optional_extra_import | Optional import works |

---

## Dependencies & Constraints

### Depends On

- **001-foundation**: Error types
- **002-event-model**: EventStore protocol
- **003-storage-sqlite**: Schema reference (parity target)
- **004-projections**: Digest comparison

### Blocks

- 006-query-layer (P5)
- 007-e2e-integration (P6)

### Frozen Decisions

- **DD-005**: SQLite (embedded) + Postgres (server)
- **DD-006**: Raw SQL via DB-API (no ORM)

---

## Files to Implement

```
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
    test_parity.py         # SQLite vs Postgres digest comparison
```

---

## SSOT References

- Section 6.1.4: Storage Columns
- Section 8.1 P4: Phase definition
- DD-005: Backend decision
- DD-006: DB-API decision
