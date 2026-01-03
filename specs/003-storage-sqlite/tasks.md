# Tasks: SQLite Storage Backend

**Input**: Design documents from `/specs/003-storage-sqlite/`
**Prerequisites**: 001-foundation, 002-event-model complete, plan.md, spec.md

**Tests**: Tests included as per SSOT P2 test cases (TC-P2-001 through TC-P2-010).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `src/`, `tests/` at repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify prerequisites and create test structure

- [x] T001 Verify 001-foundation and 002-event-model packages are complete
- [x] T002 Create src/decisiongraph/storage/sqlite/__init__.py
- [x] T003 Create src/decisiongraph/storage/sqlite/migrations/ directory
- [x] T004 Create tests/integration/test_sqlite_backend.py skeleton

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Migration engine that ALL storage functionality depends on

**Warning**: No user story work can begin until this phase is complete

- [x] T005 Implement MigrationEngine class in src/decisiongraph/storage/migrations.py:
  - Numbered .sql file discovery
  - schema_migrations tracking table
  - Atomic transaction per migration
  - Version tracking
- [x] T006 Create schema_migrations table schema
- [x] T007 Add migration engine unit tests

**Checkpoint**: Migration engine ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Database Initialization (Priority: P1)

**Goal**: Enable automatic database initialization without manual setup

**Independent Test**: Create SQLiteEventStore and check that tables exist

### Implementation for User Story 1

- [x] T008 [US1] Create src/decisiongraph/storage/sqlite/migrations/0001_event_log.sql with:
  - dg_event_log table per SSOT 6.1.4
  - log_seq as INTEGER PRIMARY KEY
  - UNIQUE on (trace_id, trace_seq)
  - UNIQUE on (producer_id, idempotency_key)
  - Indexes on event_type, correlation_id
- [x] T009 [US1] Implement SQLiteEventStore.__init__ with auto-migration in src/decisiongraph/storage/sqlite/backend.py
- [x] T010 [US1] Add TC-P2-001 (sqlite_migrate_fresh_db) test
- [x] T011 [US1] Add test for pending migrations on existing database
- [x] T012 [US1] Add test for no migrations when schema current

**Checkpoint**: Database initializes automatically

---

## Phase 4: User Story 2 - Persistent Event Storage (Priority: P1)

**Goal**: Ensure events persist to disk and survive restarts

**Independent Test**: Append events, close connection, reopen, retrieve events

### Implementation for User Story 2

- [x] T013 [US2] Implement SQLiteEventStore.append_event() in src/decisiongraph/storage/sqlite/backend.py
  - Insert event with all columns per SSOT 6.1.4
  - Return StoredEvent with log_seq and recorded_at
- [x] T014 [US2] Implement SQLiteEventStore.get_trace_events() with trace_seq ordering
- [x] T015 [US2] Implement SQLiteEventStore.list_events() with log_seq ordering
- [x] T016 [US2] Implement SQLiteEventStore.get_last_log_seq()
- [x] T017 [US2] Add TC-P2-002 (sqlite_append_persists) test
- [x] T018 [US2] Add TC-P2-005 (sqlite_trace_events_order) test
- [x] T019 [US2] Add TC-P2-006 (sqlite_list_events_order) test

**Checkpoint**: Events persist and are retrievable

---

## Phase 5: User Story 3 - Constraint Enforcement (Priority: P1)

**Goal**: Enforce database constraints for data integrity

**Independent Test**: Attempt to insert duplicate idempotency keys

### Implementation for User Story 3

- [x] T020 [US3] Implement idempotency check via UNIQUE constraint handling
- [x] T021 [US3] Implement trace_seq uniqueness enforcement
- [x] T022 [US3] Implement TraceFinished lock check (query before append)
- [x] T023 [US3] Add TC-P2-003 (sqlite_idempotency_unique) test
- [x] T024 [US3] Add TC-P2-004 (sqlite_trace_seq_unique) test
- [x] T025 [US3] Add TC-P2-008 (sqlite_finish_locks) test
- [x] T026 [US3] Add TC-P2-009 (sqlite_restart_preserves_seq) test

**Checkpoint**: Database constraints are enforced

---

## Phase 6: User Story 4 - Transactional Appends (Priority: P1)

**Goal**: Ensure atomic transactions prevent partial writes

**Independent Test**: Simulate failure mid-transaction

### Implementation for User Story 4

- [x] T027 [US4] Wrap append_event in transaction context manager
- [x] T028 [US4] Implement rollback on constraint violation
- [x] T029 [US4] Add test for transaction commit visibility
- [x] T030 [US4] Add test for transaction rollback isolation
- [x] T031 [US4] Add test for concurrent append unique log_seq

**Checkpoint**: Transactions are atomic

---

## Phase 7: User Story 5 - Query Performance (Priority: P2)

**Goal**: Ensure indexed queries for efficient lookups

**Independent Test**: EXPLAIN query plan showing index usage

### Implementation for User Story 5

- [x] T032 [US5] Verify index on trace_id in 0001_event_log.sql
- [x] T033 [US5] Verify index on correlation_id in 0001_event_log.sql
- [x] T034 [US5] Verify index on event_type in 0001_event_log.sql
- [x] T035 [US5] Add TC-P2-007 (sqlite_payload_hash_verified) test
- [x] T036 [US5] Add TC-P2-010 (sqlite_reject_invalid_payload) test
- [x] T037 [US5] Add query plan verification tests

**Checkpoint**: Queries use indexes

---

## Phase 8: Projection Tables Schema

**Purpose**: Create projection tables for Phase 004

- [x] T038 Create src/decisiongraph/storage/sqlite/migrations/0002_projections.sql with:
  - dg_cg_nodes table
  - dg_cg_edges table
  - dg_trace_summary table
  - dg_precedent_index table
  - dg_projection_meta table
- [x] T039 Add test for projection tables migration

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and integration

- [x] T040 Run all 10 P2 test cases and verify pass
- [x] T041 Verify 1000 appends complete in under 5 seconds
- [x] T042 Verify query by trace_id returns in under 50ms for 10K events
- [x] T043 Verify database survives restart with all data intact
- [x] T044 Verify mypy strict passes on new code
- [x] T045 Verify ruff check passes on new code

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Depends on 001/002 being complete
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - US1 must complete before US2, US3, US4, US5 (need schema)
  - US2, US3, US4 can run in parallel after US1
  - US5 can run parallel to US3/US4
- **Projection Tables (Phase 8)**: Can run after US1
- **Polish (Phase 9)**: Depends on all phases being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - Creates schema
- **User Story 2 (P1)**: Depends on US1 (needs tables)
- **User Story 3 (P1)**: Depends on US2 (needs append_event)
- **User Story 4 (P1)**: Depends on US2 (needs append_event)
- **User Story 5 (P2)**: Depends on US1 (needs indexes)

### Parallel Opportunities

- T013-T019 (US2), T020-T026 (US3), T027-T031 (US4) can run in parallel after US1
- T032-T037 (US5) can run parallel to US3/US4

---

## Parallel Example: After User Story 1

```bash
# Launch persistence and constraint tests together:
Task: "Implement SQLiteEventStore.append_event()"
Task: "Implement idempotency check via UNIQUE constraint"
Task: "Wrap append_event in transaction context manager"
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (Migration Engine)
3. Complete Phase 3: User Story 1 (Database Initialization)
4. Complete Phase 4: User Story 2 (Persistent Storage)
5. **STOP and VALIDATE**: Test events persist across restarts

### Incremental Delivery

1. Setup + Foundational -> Migration engine ready
2. Add User Story 1 -> Auto-initialization works
3. Add User Story 2 -> Events persist
4. Add User Story 3 -> Constraints enforced
5. Add User Story 4 -> Transactions atomic
6. Add User Story 5 -> Queries performant
7. Projection Tables -> Ready for Phase 004
8. Polish phase -> All 10 test cases pass

---

## Summary

- **Total Tasks**: 45
- **Setup Phase**: 4 tasks
- **Foundational Phase**: 3 tasks
- **User Story 1**: 5 tasks
- **User Story 2**: 7 tasks
- **User Story 3**: 7 tasks
- **User Story 4**: 5 tasks
- **User Story 5**: 6 tasks
- **Projection Tables**: 2 tasks
- **Polish Phase**: 6 tasks

**Parallel Opportunities**: US2||US3||US4 after US1, US5||US3/US4

**MVP Scope**: User Story 1 + 2 (Initialization + Persistence)

**Status**: ✅ ALL 45 TASKS COMPLETE
