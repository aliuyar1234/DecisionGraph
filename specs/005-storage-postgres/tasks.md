# Tasks: PostgreSQL Storage Backend

**Input**: Design documents from `/specs/005-storage-postgres/`
**Prerequisites**: 001-004 complete, plan.md, spec.md

**Tests**: Tests included as per SSOT P4 test cases (TC-P4-001 through TC-P4-010).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `src/`, `tests/` at repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify prerequisites and create structure

- [x] T001 Verify 001-004 packages are complete
- [x] T002 Create src/decisiongraph/storage/postgres/__init__.py
- [x] T003 Create src/decisiongraph/storage/postgres/migrations/ directory
- [x] T004 Update pyproject.toml with optional postgres extra:
  ```toml
  [project.optional-dependencies]
  postgres = ["psycopg>=3.0"]
  ```
- [x] T005 Create tests/integration/test_postgres_backend.py skeleton
- [x] T006 [P] Create tests/integration/test_parity.py skeleton

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Postgres migrations that ALL storage functionality depends on

**Warning**: No user story work can begin until this phase is complete

- [x] T007 Create src/decisiongraph/storage/postgres/migrations/0001_event_log.sql:
  - Same schema as SQLite with Postgres syntax
  - log_seq BIGSERIAL PRIMARY KEY
  - Same constraints and indexes
- [x] T008 Create src/decisiongraph/storage/postgres/migrations/0002_projections.sql:
  - Same projection tables as SQLite
- [x] T009 Extend MigrationEngine in storage/migrations.py to support Postgres
- [x] T010 Add TC-P4-001 (pg_migrate_fresh_db) test

**Checkpoint**: Postgres migrations ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Server-Grade Storage (Priority: P1)

**Goal**: Enable PostgreSQL support for server deployments

**Independent Test**: Run same test suite against Postgres

### Implementation for User Story 1

- [x] T011 [US1] Implement PostgresEventStore class in src/decisiongraph/storage/postgres/backend.py:
  - Implement EventStore protocol
  - Connection string configuration
  - Auto-migration on init
- [x] T012 [US1] Implement PostgresEventStore.append_event()
- [x] T013 [US1] Implement PostgresEventStore.get_trace_events()
- [x] T014 [US1] Implement PostgresEventStore.list_events()
- [x] T015 [US1] Implement PostgresEventStore.get_last_log_seq()
- [x] T016 [US1] Add TC-P4-002 (pg_append_persists) test
- [x] T017 [US1] Add TC-P4-003 (pg_idempotency_unique) test
- [x] T018 [US1] Add TC-P4-004 (pg_trace_seq_unique) test
- [x] T019 [US1] Add TC-P4-005 (pg_projector_runs) test
- [x] T020 [US1] Add TC-P4-007 (pg_list_events_order) test
- [x] T021 [US1] Add TC-P4-008 (pg_finish_locks) test

**Checkpoint**: PostgresEventStore implements full EventStore protocol

---

## Phase 4: User Story 2 - Backend Parity (Priority: P1)

**Goal**: Ensure SQLite and Postgres behave identically

**Independent Test**: Run parity tests with identical fixtures

### Implementation for User Story 2

- [x] T022 [US2] Implement parity test framework in tests/integration/test_parity.py
- [x] T023 [US2] Add get_trace_events parity test
- [x] T024 [US2] Add list_events parity test
- [x] T025 [US2] Add idempotency behavior parity test
- [x] T026 [US2] Add TC-P4-006 (pg_digest_matches_sqlite) test
- [x] T027 [US2] Add projector digest comparison test

**Checkpoint**: SQLite and Postgres produce identical results

---

## Phase 5: User Story 3 - Optional Dependency (Priority: P2)

**Goal**: Make Postgres an optional dependency

**Independent Test**: Import decisiongraph without psycopg installed

### Implementation for User Story 3

- [x] T028 [US3] Implement conditional import in src/decisiongraph/storage/__init__.py:
  ```python
  try:
      from .postgres import PostgresEventStore
  except ImportError:
      PostgresEventStore = None
  ```
- [x] T029 [US3] Add TC-P4-010 (pg_optional_extra_import) test
- [x] T030 [US3] Add test for graceful handling when psycopg not installed
- [x] T031 [US3] Add test for successful import when psycopg is installed

**Checkpoint**: Postgres is optional without breaking core

---

## Phase 6: Error Handling

**Purpose**: Proper error mapping for Postgres-specific errors

- [x] T032 Implement error mapping from psycopg exceptions to DecisionGraphError
- [x] T033 Add TC-P4-009 (pg_error_mapping_storage) test
- [x] T034 Add connection timeout handling
- [x] T035 Add retry logic for transient failures

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and integration

- [x] T036 Run all 10 P4 test cases and verify pass
- [x] T037 Verify 10K event append completes in under 10 seconds
- [x] T038 Verify digest parity with SQLite for golden fixture
- [x] T039 Set up Docker-based Postgres for CI tests
- [x] T040 Verify mypy strict passes on new code
- [x] T041 Verify ruff check passes on new code

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Depends on 001-004 being complete
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - US1 must complete before US2 (need PostgresEventStore)
  - US2 must complete before US3 (need working parity)
- **Error Handling (Phase 6)**: Can run parallel to US2/US3
- **Polish (Phase 7)**: Depends on all phases being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - Creates PostgresEventStore
- **User Story 2 (P1)**: Depends on US1 (needs working backend)
- **User Story 3 (P2)**: Depends on US1 (needs backend to conditionally import)

### Parallel Opportunities

- T005, T006 can run in parallel (test skeletons)
- Error Handling (Phase 6) can run parallel to US2/US3

---

## Parallel Example: Setup Phase

```bash
# Launch test skeleton creation together:
Task: "Create tests/integration/test_postgres_backend.py skeleton"
Task: "Create tests/integration/test_parity.py skeleton"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (Postgres Migrations)
3. Complete Phase 3: User Story 1 (PostgresEventStore)
4. **STOP and VALIDATE**: Test all SQLite tests pass on Postgres

### Incremental Delivery

1. Setup + Foundational -> Postgres migrations ready
2. Add User Story 1 -> PostgresEventStore works
3. Add User Story 2 -> Parity verified
4. Add User Story 3 -> Optional import works
5. Error Handling -> Proper error mapping
6. Polish phase -> All 10 test cases pass

---

## Summary

- **Total Tasks**: 41
- **Setup Phase**: 6 tasks
- **Foundational Phase**: 4 tasks
- **User Story 1**: 11 tasks
- **User Story 2**: 6 tasks
- **User Story 3**: 4 tasks
- **Error Handling**: 4 tasks
- **Polish Phase**: 6 tasks

**Parallel Opportunities**: T005||T006, Error Handling||US2/US3

**MVP Scope**: User Story 1 (PostgresEventStore)

**Note**: Requires Docker for Postgres integration tests
