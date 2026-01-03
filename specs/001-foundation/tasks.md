# Tasks: DecisionGraph Foundation

**Input**: Design documents from `/specs/001-foundation/`
**Prerequisites**: plan.md (required), spec.md (required for user stories)

**Tests**: Tests included as per SSOT P0 test cases (TC-P0-001 through TC-P0-010).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `src/`, `tests/` at repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Create pyproject.toml with Python 3.12+ requirement and project metadata
- [x] T002 [P] Create LICENSE file with Apache-2.0 license text
- [x] T003 [P] Create importlinter.ini with module boundary contracts per SSOT 5.3
- [x] T004 [P] Create README.md with minimal usage documentation
- [x] T005 Create package structure under src/decisiongraph/ with __init__.py

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**Warning**: No user story work can begin until this phase is complete

- [x] T006 Implement src/decisiongraph/errors.py with DecisionGraphError and error codes per SSOT 7.2/11.1
- [x] T007 [P] Implement src/decisiongraph/ids.py with UUID generation utilities
- [x] T008 [P] Implement src/decisiongraph/time.py with RFC3339 time utilities
- [x] T009 Create stub modules for future phases:
  - src/decisiongraph/api.py (stub)
  - src/decisiongraph/serialization/__init__.py
  - src/decisiongraph/serialization/canonical_json.py (stub with NotImplementedError)
  - src/decisiongraph/serialization/hashing.py (sha256_hex, sha256_prefixed)
  - src/decisiongraph/storage/__init__.py
  - src/decisiongraph/storage/interface.py (stub)
  - src/decisiongraph/projections/__init__.py
  - src/decisiongraph/projections/interfaces.py (stub)
  - src/decisiongraph/query/__init__.py
  - src/decisiongraph/query/filters.py (stub)
  - src/decisiongraph/query/events.py (stub)
  - src/decisiongraph/query/graph.py (stub)
  - src/decisiongraph/query/precedents.py (stub)
  - src/decisiongraph/policy/__init__.py
  - src/decisiongraph/policy/interfaces.py (stub)
  - src/decisiongraph/testing/__init__.py
  - src/decisiongraph/testing/fakes.py (stub)
  - src/decisiongraph/testing/golden.py (stub)

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Package Installation (Priority: P1)

**Goal**: Enable developers to install the package via pip and import it

**Independent Test**: Run `pip install -e .` in a fresh virtualenv and verify import works

### Implementation for User Story 1

- [x] T010 [US1] Expose __version__ in src/decisiongraph/__init__.py
- [x] T011 [US1] Configure build system in pyproject.toml (setuptools/hatch)
- [x] T012 [US1] Verify pip install -e . completes without errors
- [x] T013 [US1] Verify import decisiongraph succeeds

**Checkpoint**: Package is installable and importable

---

## Phase 4: User Story 2 - Error Handling Contract (Priority: P1)

**Goal**: Provide structured error codes for programmatic handling

**Independent Test**: Catch DecisionGraphError and check its code attribute

### Implementation for User Story 2

- [x] T014 [US2] Verify DecisionGraphError has code and message attributes in src/decisiongraph/errors.py
- [x] T015 [US2] Implement all error codes from SSOT 7.2 as constants
- [x] T016 [US2] Implement __str__ method returning "{code}: {message}" format
- [x] T017 [US2] Create tests/unit/test_errors.py with TC-P0-002 (error_codes_enum)

**Checkpoint**: Error handling contract is complete

---

## Phase 5: User Story 3 - Domain Types Available (Priority: P2)

**Goal**: Provide type-safe domain primitives for IDE and type checker validation

**Independent Test**: Import types and construct instances with valid data

### Implementation for User Story 3

- [x] T018 [P] [US3] Implement ActorRef dataclass in src/decisiongraph/domain/types.py
- [x] T019 [P] [US3] Implement EntityRef dataclass in src/decisiongraph/domain/types.py
- [x] T020 [P] [US3] Implement Value dataclass in src/decisiongraph/domain/types.py
- [x] T021 [P] [US3] Implement Fact dataclass in src/decisiongraph/domain/types.py
- [x] T022 [P] [US3] Implement SourceObjectRef dataclass in src/decisiongraph/domain/types.py
- [x] T023 [P] [US3] Implement EvidenceRef dataclass in src/decisiongraph/domain/types.py
- [x] T024 [P] [US3] Implement Violation dataclass in src/decisiongraph/domain/types.py
- [x] T025 [P] [US3] Implement Change dataclass in src/decisiongraph/domain/types.py
- [x] T026 [P] [US3] Implement ApprovalSubject dataclass in src/decisiongraph/domain/types.py
- [x] T027 [US3] Create src/decisiongraph/domain/__init__.py exposing all types
- [x] T028 [US3] Create src/decisiongraph/domain/events.py with EventEnvelope/StoredEvent stubs per SSOT 11.3
- [x] T029 [US3] Create src/decisiongraph/domain/validation.py stub
- [x] T030 [US3] Create tests/unit/test_domain_types.py with TC-P0-003 (dataclasses_construct)

**Checkpoint**: Domain types are available and constructable

---

## Phase 6: User Story 4 - Module Boundaries Enforced (Priority: P2)

**Goal**: Enforce module boundaries in CI to prevent architectural violations

**Independent Test**: Run import-linter and check exit code

### Implementation for User Story 4

- [x] T031 [US4] Configure import-linter contracts in importlinter.ini per SSOT 5.3
- [x] T032 [US4] Add domain isolation contract (domain cannot import storage/projections/query/api)
- [x] T033 [US4] Add query isolation contract (query cannot import concrete backends)
- [x] T034 [US4] Create tests/unit/test_bootstrap.py with TC-P0-006 (import_linter_contract_domain_pure)
- [x] T035 [US4] Add TC-P0-007 (no_cycles) test for circular import detection

**Checkpoint**: Module boundaries are enforced

---

## Phase 7: User Story 5 - Type Checking Passes (Priority: P2)

**Goal**: Ensure mypy strict mode passes for type safety

**Independent Test**: Run `mypy src/` with strict config and check exit code

### Implementation for User Story 5

- [x] T036 [US5] Configure mypy strict mode in pyproject.toml
- [x] T037 [US5] Configure ruff in pyproject.toml
- [x] T038 [US5] Ensure all domain dataclasses have full type annotations
- [x] T039 [US5] Create tests/unit/test_bootstrap.py with TC-P0-004 (mypy_strict_pass)
- [x] T040 [US5] Add TC-P0-005 (ruff_pass) test

**Checkpoint**: Type checking passes

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and remaining test cases

- [x] T041 Add TC-P0-001 (import_root) test in tests/unit/test_bootstrap.py
- [x] T042 Add TC-P0-008 (packaging_src_layout) test
- [x] T043 Add TC-P0-009 (api_module_importable) test
- [x] T044 Add TC-P0-010 (version_exposed) test
- [x] T045 Run all tests and verify 10/10 pass
- [x] T046 Verify pip install -e . completes in under 30 seconds
- [x] T047 Verify import decisiongraph completes in under 1 second

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - US1 and US2 can proceed in parallel
  - US3, US4, US5 can proceed in parallel after US1/US2
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 3 (P2)**: Can start after Foundational - Independently testable
- **User Story 4 (P2)**: Can start after Foundational - Independently testable
- **User Story 5 (P2)**: Depends on US3 (needs types to type-check)

### Parallel Opportunities

- T002, T003, T004 can run in parallel (different files)
- T007, T008 can run in parallel
- T018-T026 can all run in parallel (different dataclasses)

---

## Parallel Example: User Story 3

```bash
# Launch all domain type implementations together:
Task: "Implement ActorRef dataclass in src/decisiongraph/domain/types.py"
Task: "Implement EntityRef dataclass in src/decisiongraph/domain/types.py"
Task: "Implement Value dataclass in src/decisiongraph/domain/types.py"
# ... etc
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Package Installation)
4. **STOP and VALIDATE**: Test package installation independently
5. Continue to US2 (Error Handling)

### Incremental Delivery

1. Setup + Foundational -> Foundation ready
2. Add User Story 1 -> pip install works
3. Add User Story 2 -> Error handling works
4. Add User Story 3 -> Domain types available
5. Add User Story 4 -> Module boundaries enforced
6. Add User Story 5 -> Type checking passes
7. Polish phase -> All 10 test cases pass

---

## Summary

- **Total Tasks**: 47
- **Setup Phase**: 5 tasks
- **Foundational Phase**: 4 tasks
- **User Story 1**: 4 tasks
- **User Story 2**: 4 tasks
- **User Story 3**: 13 tasks
- **User Story 4**: 5 tasks
- **User Story 5**: 5 tasks
- **Polish Phase**: 7 tasks

**Parallel Opportunities**: T002-T004, T007-T008, T018-T026

**MVP Scope**: User Story 1 (Package Installation)

**Status**: ✅ ALL 47 TASKS COMPLETE
