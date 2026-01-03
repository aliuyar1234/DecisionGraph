# Tasks: Event Model & Serialization

**Input**: Design documents from `/specs/002-event-model/`
**Prerequisites**: 001-foundation complete, plan.md, spec.md

**Tests**: Tests included as per SSOT P1 test cases (TC-P1-001 through TC-P1-011).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `src/`, `tests/` at repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify 001-foundation is complete and test structure ready

- [x] T001 Verify 001-foundation package is installed and importable
- [x] T002 Create tests/unit/test_canonical_json.py skeleton
- [x] T003 [P] Create tests/unit/test_event_model.py skeleton
- [x] T004 [P] Create tests/unit/test_inmemory_store.py skeleton
- [x] T005 [P] Create tests/unit/test_pii_guard.py skeleton

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core serialization and hashing that ALL stories depend on

**Warning**: No user story work can begin until this phase is complete

- [x] T006 Implement canonicalize_json(obj) in src/decisiongraph/serialization/canonical_json.py per SSOT 6.1.5
  - Sorted keys lexicographically
  - No whitespace
  - No floats at any nesting depth
  - UTF-8 encoding
- [x] T007 Verify sha256_hex and sha256_prefixed in src/decisiongraph/serialization/hashing.py
- [x] T008 Create tests for canonical JSON (TC-P1-001, TC-P1-002)

**Checkpoint**: Canonical serialization ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Emit Decision Trace Events (Priority: P1)

**Goal**: Enable workflow developers to emit decision trace events to the append-only log

**Independent Test**: Call start_trace() and verify TraceStarted event is stored

### Implementation for User Story 1

- [x] T009 [US1] Implement EventEnvelope dataclass in src/decisiongraph/domain/events.py per SSOT 11.3
- [x] T010 [US1] Implement StoredEvent dataclass in src/decisiongraph/domain/events.py per SSOT 11.3
- [x] T011 [US1] Implement 10 event type payload dataclasses in src/decisiongraph/domain/events.py:
  - TraceStartedPayload
  - InputObservedPayload
  - EntityObservedPayload
  - PolicyEvaluatedPayload
  - ExceptionRequestedPayload
  - ApprovalRecordedPayload
  - PrecedentCitedPayload
  - ActionProposedPayload
  - ActionCommittedPayload
  - TraceFinishedPayload
- [x] T012 [US1] Implement EventStore protocol in src/decisiongraph/storage/interface.py per SSOT 11.6
- [x] T013 [US1] Implement emission methods in src/decisiongraph/api.py (Note: API stub exists, full emission via InMemoryEventStore)
- [x] T014 [US1] Add tests for event emission in tests/unit/test_event_model.py

**Checkpoint**: Event emission works with trace_seq enforcement

---

## Phase 4: User Story 2 - Canonical JSON Serialization (Priority: P1)

**Goal**: Ensure deterministic JSON serialization for reproducible payload hashes

**Independent Test**: Serialize same object twice and compare outputs

### Implementation for User Story 2

- [x] T015 [US2] Implement float rejection at any nesting depth in canonical_json.py
- [x] T016 [US2] Add TC-P1-001 (canonical_json_key_order) test
- [x] T017 [US2] Add TC-P1-002 (canonical_json_no_whitespace) test
- [x] T018 [US2] Add TC-P1-003 (hash_matches) test - payload_hash matches recomputed hash
- [x] T019 [US2] Add TC-P1-004 (reject_float) test

**Checkpoint**: Canonical JSON serialization is deterministic

---

## Phase 5: User Story 3 - Idempotency Handling (Priority: P1)

**Goal**: Enable idempotent event emission so retries don't create duplicates

**Independent Test**: Emit same event twice with same idempotency key

### Implementation for User Story 3

- [x] T020 [US3] Implement idempotency key validation (max 200 bytes) in src/decisiongraph/domain/validation.py
- [x] T021 [US3] Implement idempotency check in EventStore.append_event() (scope: producer_id + idempotency_key)
- [x] T022 [US3] Add TC-P1-005 (idempotency_repeat_success) test
- [x] T023 [US3] Add TC-P1-006 (idempotency_conflict_error) test

**Checkpoint**: Idempotent retries work correctly

---

## Phase 6: User Story 4 - Trace Sequence Enforcement (Priority: P1)

**Goal**: Ensure trace_seq is strictly monotonic for unambiguous event ordering

**Independent Test**: Check trace_seq values after multiple emissions

### Implementation for User Story 4

- [x] T024 [US4] Implement trace_seq auto-increment starting at 0 in event emission
- [x] T025 [US4] Implement trace_seq validation (must be exactly N+1)
- [x] T026 [US4] Implement TraceFinished lock (no appends after finish)
- [x] T027 [US4] Add TC-P1-007 (trace_seq_monotonic_enforced) test
- [x] T028 [US4] Add TC-P1-008 (trace_finish_locks) test

**Checkpoint**: Trace sequence is strictly monotonic

---

## Phase 7: User Story 5 - PII/Secret Guard (Priority: P1)

**Goal**: Reject forbidden content to prevent secrets in event log

**Independent Test**: Attempt to store payload containing "Bearer "

### Implementation for User Story 5

- [x] T029 [US5] Implement PII guard in src/decisiongraph/domain/validation.py with forbidden substrings:
  - "Bearer "
  - "xoxb-"
  - "-----BEGIN"
  - (and other substrings from SSOT 6.1.8.1)
- [x] T030 [US5] Integrate PII guard check before event storage
- [x] T031 [US5] Add TC-P1-011 (pii_guard_rejects) test
- [x] T032 [US5] Add tests for each forbidden substring type

**Checkpoint**: PII guard rejects forbidden content

---

## Phase 8: User Story 6 - InMemory Store for Testing (Priority: P2)

**Goal**: Provide in-memory event store for unit tests without database

**Independent Test**: Run tests with InMemoryEventStore without database setup

### Implementation for User Story 6

- [x] T033 [US6] Implement InMemoryEventStore in src/decisiongraph/testing/fakes.py
  - Implement append_event() with idempotency via dict lookup
  - Implement get_trace_events() with trace_seq order
  - Implement list_events() with log_seq order
  - Implement get_last_log_seq()
  - Enforce trace_seq validation
- [x] T034 [US6] Add TC-P1-009 (append_returns_log_seq) test
- [x] T035 [US6] Add TC-P1-010 (get_trace_events_ordered) test
- [x] T036 [US6] Add tests for list_events ordering

**Checkpoint**: InMemoryEventStore works for unit testing

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and integration

- [x] T037 Run all 11 P1 test cases and verify pass
- [x] T038 Verify canonical JSON produces identical output 100% of time
- [x] T039 Verify idempotent retries return within 10ms (in-memory)
- [x] T040 Verify mypy strict passes on new code
- [x] T041 Verify ruff check passes on new code

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Depends on 001-foundation being complete
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phase 3-8)**: All depend on Foundational phase completion
  - US1 must complete before US3, US4 (need EventStore)
  - US2 can run parallel to US1
  - US5, US6 can run parallel after US1
- **Polish (Phase 9)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - Provides event model
- **User Story 2 (P1)**: Can start after Foundational - Parallel to US1
- **User Story 3 (P1)**: Depends on US1 (needs EventStore)
- **User Story 4 (P1)**: Depends on US1 (needs event emission)
- **User Story 5 (P1)**: Depends on US1 (needs validation hook)
- **User Story 6 (P2)**: Depends on US1 (implements EventStore protocol)

### Parallel Opportunities

- T002, T003, T004, T005 can run in parallel (test skeletons)
- T015-T019 (US2) can run parallel to T009-T014 (US1)
- T029-T032 (US5) can run parallel to T033-T036 (US6) after US1

---

## Parallel Example: User Story 2

```bash
# Launch all canonical JSON tests together:
Task: "Add TC-P1-001 (canonical_json_key_order) test"
Task: "Add TC-P1-002 (canonical_json_no_whitespace) test"
Task: "Add TC-P1-003 (hash_matches) test"
Task: "Add TC-P1-004 (reject_float) test"
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (canonical JSON + hashing)
3. Complete Phase 3: User Story 1 (Event Emission)
4. Complete Phase 4: User Story 2 (Canonical JSON)
5. **STOP and VALIDATE**: Test event emission with canonical hashing

### Incremental Delivery

1. Setup + Foundational -> Serialization ready
2. Add User Story 1 -> Event emission works
3. Add User Story 2 -> Canonical JSON deterministic
4. Add User Story 3 -> Idempotency works
5. Add User Story 4 -> Trace sequence enforced
6. Add User Story 5 -> PII guard active
7. Add User Story 6 -> InMemory store for testing
8. Polish phase -> All 11 test cases pass

---

## Summary

- **Total Tasks**: 41
- **Setup Phase**: 5 tasks
- **Foundational Phase**: 3 tasks
- **User Story 1**: 6 tasks
- **User Story 2**: 5 tasks
- **User Story 3**: 4 tasks
- **User Story 4**: 5 tasks
- **User Story 5**: 4 tasks
- **User Story 6**: 4 tasks
- **Polish Phase**: 5 tasks

**Parallel Opportunities**: T002-T005, US1||US2, US5||US6

**MVP Scope**: User Story 1 + 2 (Event Emission + Canonical JSON)

**Status**: ✅ ALL 41 TASKS COMPLETE
