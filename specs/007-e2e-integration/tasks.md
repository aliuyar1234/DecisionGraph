# Tasks: End-to-End Integration & Documentation

**Input**: Design documents from `/specs/007-e2e-integration/`
**Prerequisites**: 001-006 complete, plan.md, spec.md

**Tests**: Tests included as per SSOT P6 test cases (TC-P6-001 through TC-P6-010).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `src/`, `tests/` at repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify all previous phases complete and create structure

- [x] T001 Verify all 001-006 packages are complete and tests pass
- [x] T002 Create tests/golden/ directory structure
- [x] T003 [P] Create tests/golden/renewal/ directory
- [x] T004 [P] Create tests/golden/support/ directory
- [x] T005 [P] Create tests/golden/dealdesk/ directory
- [x] T006 Create tests/e2e/ directory
- [x] T007 Create tests/e2e/test_fixtures.py skeleton
- [x] T008 [P] Create tests/e2e/test_cli.py skeleton
- [x] T009 [P] Create tests/e2e/test_docs.py skeleton

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Golden fixture utilities that ALL E2E tests depend on

**Warning**: No user story work can begin until this phase is complete

- [x] T010 Implement load_fixture(path) -> list[EventEnvelope] in src/decisiongraph/testing/golden.py
- [x] T011 Implement replay_fixture(store, events) -> str (returns digest) in golden.py
- [x] T012 Implement validate_fixture(path) -> bool in golden.py
- [x] T013 Define fixture JSON format:
  ```json
  {
    "scenario": "name",
    "description": "...",
    "events": [...],
    "expected_digest": "sha256:..."
  }
  ```
- [x] T014 Add fixture utility tests

**Checkpoint**: Golden fixture utilities ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Golden Fixture Validation (Priority: P1)

**Goal**: Catch regressions automatically via golden fixtures

**Independent Test**: Run fixture replay and compare digest

### Implementation for User Story 1

- [x] T015 [US1] Create tests/golden/renewal/events.json with 9 events from SSOT 10.1:
  - TraceStarted
  - EntityObserved (customer)
  - InputObserved (renewal request)
  - PolicyEvaluated (discount policy)
  - PrecedentCited
  - ExceptionRequested
  - ApprovalRecorded
  - ActionCommitted
  - TraceFinished
- [x] T016 [P] [US1] Create tests/golden/renewal/expected_digest.txt
- [x] T017 [P] [US1] Create tests/golden/support/events.json from SSOT 10.2 (Support Escalation)
- [x] T018 [P] [US1] Create tests/golden/support/expected_digest.txt
- [x] T019 [P] [US1] Create tests/golden/dealdesk/events.json from SSOT 10.3 (Deal Desk)
- [x] T020 [P] [US1] Create tests/golden/dealdesk/expected_digest.txt
- [x] T021 [US1] Add TC-P6-001 (fixture_renewal_digest) test
- [x] T022 [US1] Add TC-P6-003 (fixture_support_digest) test
- [x] T023 [US1] Add TC-P6-005 (fixture_dealdesk_digest) test

**Checkpoint**: All 3 fixtures replay with correct digests

---

## Phase 4: User Story 2 - E2E Query Verification (Priority: P1)

**Goal**: Validate query behavior on fixtures

**Independent Test**: Run queries on fixtures and compare to expected results

### Implementation for User Story 2

- [x] T024 [US2] Add TC-P6-002 (fixture_renewal_queries) test:
  - get_trace_events returns 9 events in correct order
  - get_context_subgraph returns expected nodes/edges
  - find_precedents returns cited trace
- [x] T025 [US2] Add TC-P6-004 (fixture_support_queries) test
- [x] T026 [US2] Add TC-P6-006 (fixture_dealdesk_queries) test
- [x] T027 [US2] Add test for precedent citation verification
- [x] T028 [US2] Add test for entity graph structure

**Checkpoint**: Queries return expected results on fixtures

---

## Phase 5: User Story 3 - Documentation Accuracy (Priority: P1)

**Goal**: Ensure README examples work correctly

**Independent Test**: Execute README code snippets

### Implementation for User Story 3

- [x] T029 [US3] Update README.md with:
  - Installation instructions
  - Basic usage examples
  - API overview
  - Quick start guide
- [x] T030 [US3] Create executable code examples in README
- [x] T031 [US3] Add TC-P6-009 (docs_examples_compile) test
- [x] T032 [US3] Add TC-P6-010 (no_chain_of_thought) test
- [x] T033 [US3] Verify README doesn't contradict SSOT

**Checkpoint**: Documentation is accurate and runnable

---

## Phase 6: User Story 4 - Optional CLI for Debugging (Priority: P3)

**Goal**: Provide CLI tool for trace inspection and replay

**Independent Test**: Run CLI commands

### Implementation for User Story 4

- [x] T034 [US4] Implement CLI entry point in src/decisiongraph/__main__.py:
  - python -m decisiongraph replay <db> -> Rebuild projections, print digest
  - python -m decisiongraph dump-trace <db> <trace_id> -> Print events
- [x] T035 [US4] Ensure all CLI operations are read-only
- [x] T036 [US4] Add TC-P6-007 (cli_replay_outputs_digest) test
- [x] T037 [US4] Add TC-P6-008 (cli_dump_trace_stable) test
- [x] T038 [US4] Add helpful error messages for missing database/trace

**Checkpoint**: CLI provides debugging capabilities

---

## Phase 7: No Chain-of-Thought Verification

**Purpose**: Ensure fixtures don't contain internal reasoning

- [x] T039 Implement CoT detection in fixture validation
- [x] T040 Add test scanning all fixtures for CoT patterns
- [x] T041 Add test verifying no "thinking", "reasoning", "let me" in events

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and integration

- [x] T042 Run all 10 P6 test cases and verify pass
- [x] T043 Verify all 3 fixtures replay successfully
- [x] T044 Verify digests match expected values 100%
- [x] T045 Verify README examples execute without errors
- [x] T046 Verify mypy strict passes on new code
- [x] T047 Verify ruff check passes on new code
- [x] T048 Run full test suite (P0-P6) and verify all pass

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Depends on 001-006 being complete
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - US1 must complete before US2 (need fixtures for queries)
  - US3 can run parallel to US1/US2
  - US4 can run parallel (optional feature)
- **CoT Verification (Phase 7)**: Can run after US1
- **Polish (Phase 8)**: Depends on all phases being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - Creates fixtures
- **User Story 2 (P1)**: Depends on US1 (needs fixtures to query)
- **User Story 3 (P1)**: Can run parallel (documentation)
- **User Story 4 (P3)**: Can run parallel (optional CLI)

### Parallel Opportunities

- T003, T004, T005 can run in parallel (directories)
- T007, T008, T009 can run in parallel (test skeletons)
- T016-T020 can run in parallel (fixture files)
- US3 and US4 can run parallel to US1/US2

---

## Parallel Example: User Story 1 Fixtures

```bash
# Launch all fixture file creation together:
Task: "Create tests/golden/renewal/events.json"
Task: "Create tests/golden/support/events.json"
Task: "Create tests/golden/dealdesk/events.json"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (Fixture Utilities)
3. Complete Phase 3: User Story 1 (Golden Fixtures)
4. **STOP and VALIDATE**: Test all 3 fixtures replay with correct digests

### Incremental Delivery

1. Setup + Foundational -> Fixture utilities ready
2. Add User Story 1 -> 3 golden fixtures created
3. Add User Story 2 -> Query verification on fixtures
4. Add User Story 3 -> Documentation accurate
5. Add User Story 4 -> CLI available (optional)
6. CoT Verification -> No reasoning in fixtures
7. Polish phase -> All 10 test cases pass

---

## Summary

- **Total Tasks**: 48
- **Setup Phase**: 9 tasks
- **Foundational Phase**: 5 tasks
- **User Story 1**: 9 tasks
- **User Story 2**: 5 tasks
- **User Story 3**: 5 tasks
- **User Story 4**: 5 tasks
- **CoT Verification**: 3 tasks
- **Polish Phase**: 7 tasks

**Parallel Opportunities**: T003-T005, T007-T009, T016-T020, US3||US4

**MVP Scope**: User Story 1 (Golden Fixture Validation)

**Final Validation**: All P0-P6 test cases pass (10+11+10+13+10+12+10 = 76 tests)

**Status**: ✅ ALL 48 TASKS COMPLETE
