# Tasks: Projection Engine & Context Graph

**Input**: Design documents from `/specs/004-projections/`
**Prerequisites**: 001-003 complete, plan.md, spec.md

**Tests**: Tests included as per SSOT P3 test cases (TC-P3-001 through TC-P3-013).

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

- [x] T001 Verify 001-003 packages are complete
- [x] T002 Verify 0002_projections.sql migration exists and tables created
- [x] T003 Create tests/unit/test_projector.py skeleton
- [x] T004 [P] Create tests/unit/test_digests.py skeleton
- [x] T005 [P] Create tests/integration/test_projection_replay.py skeleton

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Projector protocol that ALL projection functionality depends on

**Warning**: No user story work can begin until this phase is complete

- [x] T006 Define Projector protocol in src/decisiongraph/projections/interfaces.py:
  - project_event(event: StoredEvent) -> None
  - rebuild() -> None
  - get_cursor() -> int (last_applied_log_seq)
- [x] T007 Define Node and Edge dataclasses for context graph
- [x] T008 Add projector protocol tests

**Checkpoint**: Projector protocol defined - user story implementation can now begin

---

## Phase 3: User Story 1 - Build Context Graph from Events (Priority: P1)

**Goal**: Transform events into a graph for visualizing decision relationships

**Independent Test**: Replay events and check node/edge counts

### Implementation for User Story 1

- [x] T009 [US1] Implement context_graph.py node creation logic in src/decisiongraph/projections/context_graph.py:
  - Node key format: {node_type}:{node_id}
  - Node types: trace, entity, input, policy, exception, action, actor
- [x] T010 [US1] Implement edge creation per SSOT 6.2.4:
  - Edge key format: {edge_type}:{from_key}:{to_key}:{event_id}
- [x] T011 [US1] Implement 9 edge types:
  - trace_involves_entity
  - trace_observed_input
  - trace_evaluated_policy
  - trace_requested_exception
  - exception_approved_by
  - trace_cited_precedent
  - trace_proposed_action
  - trace_committed_action
  - action_targets_entity
- [x] T012 [US1] Implement node/edge insertion into dg_cg_nodes and dg_cg_edges tables
- [x] T013 [US1] Add TC-P3-001 (projector_full_replay_builds_graph) test
- [x] T014 [US1] Add TC-P3-006 (graph_nodes_keys) test
- [x] T015 [US1] Add TC-P3-007 (graph_edges_keys) test
- [x] T016 [US1] Add TC-P3-008 (exception_pseudo_node_created) test
- [x] T017 [US1] Add TC-P3-009 (action_pseudo_node_created) test
- [x] T018 [US1] Add TC-P3-011 (action_targets_entity_edge_required) test

**Checkpoint**: Context graph builds correctly from events

---

## Phase 4: User Story 2 - Deterministic Replay (Priority: P1)

**Goal**: Ensure projection rebuild produces identical results for data integrity

**Independent Test**: Rebuild projections twice and compare digests

### Implementation for User Story 2

- [x] T019 [US2] Implement projector.py main projector in src/decisiongraph/projections/projector.py:
  - Process events in log_seq order
  - Update projections atomically
  - Track cursor in dg_projection_meta
  - Resume from cursor on restart
- [x] T020 [US2] Implement cursor tracking (last_applied_log_seq)
- [x] T021 [US2] Implement payload_hash verification on replay
- [x] T022 [US2] Add TC-P3-002 (projector_digest_stable) test
- [x] T023 [US2] Add TC-P3-003 (projector_resume_cursor) test
- [x] T024 [US2] Add TC-P3-004 (projector_reject_bad_payload_hash) test
- [x] T025 [US2] Add TC-P3-005 (projector_reject_trace_seq_gap) test

**Checkpoint**: Replay produces identical results

---

## Phase 5: User Story 3 - Trace Summary for Precedent Search (Priority: P1)

**Goal**: Create trace summaries for quick precedent search

**Independent Test**: Finish a trace and check dg_trace_summary table

### Implementation for User Story 3

- [x] T026 [US3] Implement dg_trace_summary updates on TraceStarted:
  - Create row with workflow, title, started_at
- [x] T027 [US3] Implement dg_trace_summary updates on TraceFinished:
  - Set finished_log_seq, finished_at, outcome
- [x] T028 [US3] Add test for trace summary creation
- [x] T029 [US3] Add test for unfinished trace (outcome null)
- [x] T030 [US3] Add test for finished trace (outcome set)

**Checkpoint**: Trace summaries available for search

---

## Phase 6: User Story 4 - Precedent Index for Fast Lookup (Priority: P1)

**Goal**: Index policy/exception data for fast lookups without graph traversal

**Independent Test**: Query dg_precedent_index by policy_id

### Implementation for User Story 4

- [x] T031 [US4] Implement dg_precedent_index updates on TraceFinished:
  - Create rows for each PrecedentCited in trace
  - Include cited_trace_id, reason, similarity_score
- [x] T032 [US4] Ensure only finished traces are indexed
- [x] T033 [US4] Add test for precedent index on PrecedentCited
- [x] T034 [US4] Add test for precedent index query
- [x] T035 [US4] Add test verifying unfinished traces not in index

**Checkpoint**: Precedent index enables fast lookup

---

## Phase 7: User Story 5 - Digest Verification (Priority: P2)

**Goal**: Compute projection digests for determinism enforcement in CI

**Independent Test**: Compute digest and compare to golden fixture

### Implementation for User Story 5

- [x] T036 [US5] Implement compute_context_graph_digest() in src/decisiongraph/projections/digests.py:
  - Canonical JSON over sorted rows
  - SHA-256 hash
  - Exclude recorded_at (wall-clock)
  - attrs_json MUST be {}
- [x] T037 [US5] Implement compute_precedent_index_digest()
- [x] T038 [US5] Add TC-P3-010 (subgraph_ordering) test
- [x] T039 [US5] Add TC-P3-012 (digest_ignores_recorded_at) test
- [x] T040 [US5] Add TC-P3-013 (projection_attrs_are_empty) test
- [x] T041 [US5] Add digest stability test across multiple rebuilds

**Checkpoint**: Digests are deterministic

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and integration

- [x] T042 Run all 13 P3 test cases and verify pass
- [x] T043 Verify full replay of 10K events completes in under 30 seconds
- [x] T044 Verify incremental projection of 100 new events in under 1 second
- [x] T045 Verify digest is stable across 100 replay runs
- [x] T046 Verify mypy strict passes on new code
- [x] T047 Verify ruff check passes on new code

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Depends on 001-003 being complete
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - US1 must complete before US2 (need graph building)
  - US2, US3, US4 can run in parallel after US1
  - US5 depends on US1, US2 (needs graph + replay)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - Builds graph
- **User Story 2 (P1)**: Depends on US1 (needs graph to replay)
- **User Story 3 (P1)**: Can run parallel to US2 after US1
- **User Story 4 (P1)**: Can run parallel to US2, US3 after US1
- **User Story 5 (P2)**: Depends on US1, US2 (needs stable graph)

### Parallel Opportunities

- T003, T004, T005 can run in parallel (test skeletons)
- US2, US3, US4 can run in parallel after US1

---

## Parallel Example: After User Story 1

```bash
# Launch replay and indexing together:
Task: "Implement projector.py main projector"
Task: "Implement dg_trace_summary updates on TraceStarted"
Task: "Implement dg_precedent_index updates on TraceFinished"
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (Projector Protocol)
3. Complete Phase 3: User Story 1 (Context Graph)
4. Complete Phase 4: User Story 2 (Deterministic Replay)
5. **STOP and VALIDATE**: Test graph builds and digests stable

### Incremental Delivery

1. Setup + Foundational -> Projector protocol ready
2. Add User Story 1 -> Context graph builds
3. Add User Story 2 -> Replay deterministic
4. Add User Story 3 -> Trace summaries available
5. Add User Story 4 -> Precedent index ready
6. Add User Story 5 -> Digests for CI
7. Polish phase -> All 13 test cases pass

---

## Summary

- **Total Tasks**: 47
- **Setup Phase**: 5 tasks
- **Foundational Phase**: 3 tasks
- **User Story 1**: 10 tasks
- **User Story 2**: 7 tasks
- **User Story 3**: 5 tasks
- **User Story 4**: 5 tasks
- **User Story 5**: 6 tasks
- **Polish Phase**: 6 tasks

**Parallel Opportunities**: T003-T005, US2||US3||US4 after US1

**MVP Scope**: User Story 1 + 2 (Context Graph + Deterministic Replay)

**Status**: ✅ ALL 47 TASKS COMPLETE
