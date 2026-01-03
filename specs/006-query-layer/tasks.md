# Tasks: Query Layer & Precedent Search

**Input**: Design documents from `/specs/006-query-layer/`
**Prerequisites**: 001-004 complete (005 optional), plan.md, spec.md

**Tests**: Tests included as per SSOT P5 test cases (TC-P5-001 through TC-P5-012).

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
- [x] T002 Create tests/unit/test_query_filters.py skeleton
- [x] T003 [P] Create tests/integration/test_queries.py skeleton
- [x] T004 [P] Create tests/integration/test_precedent_search.py skeleton

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Filter and type definitions that ALL query functionality depends on

**Warning**: No user story work can begin until this phase is complete

- [x] T005 Implement EventFilter dataclass in src/decisiongraph/query/filters.py
- [x] T006 [P] Implement GraphFilter dataclass in src/decisiongraph/query/filters.py
- [x] T007 [P] Implement GraphEdgeCursor dataclass in src/decisiongraph/query/filters.py
- [x] T008 Implement NodeRef dataclass in src/decisiongraph/query/graph.py
- [x] T009 Add filter validation tests

**Checkpoint**: Filter types defined - user story implementation can now begin

---

## Phase 3: User Story 1 - Query Trace Events (Priority: P1)

**Goal**: Enable retrieval of events for a trace

**Independent Test**: Store events and query by trace_id

### Implementation for User Story 1

- [x] T010 [US1] Implement TraceSummary dataclass in src/decisiongraph/query/events.py
- [x] T011 [US1] Implement get_trace_summary(trace_id) -> TraceSummary in src/decisiongraph/query/events.py
- [x] T012 [US1] Implement get_trace_events(trace_id, filter) -> list[StoredEvent]
- [x] T013 [US1] Implement list_events(filter) -> list[StoredEvent]
- [x] T014 [US1] Add TC-P5-001 (list_events_by_type) test
- [x] T015 [US1] Add TC-P5-002 (list_events_by_trace) test
- [x] T016 [US1] Add TC-P5-003 (list_events_by_log_seq_range) test
- [x] T017 [US1] Add TC-P5-004 (trace_summary_unfinished) test
- [x] T018 [US1] Add TC-P5-005 (trace_summary_finished) test
- [x] T019 [US1] Add TC-P5-006 (trace_events_pagination) test

**Checkpoint**: Trace event queries work

---

## Phase 4: User Story 2 - Query Context Subgraph (Priority: P1)

**Goal**: Query scoped subgraph for decision relationship navigation

**Independent Test**: Query around trace node with depth=1

### Implementation for User Story 2

- [x] T020 [US2] Implement ContextSubgraph dataclass in src/decisiongraph/query/graph.py:
  - nodes: list[Node]
  - edges: list[Edge]
  - truncated: bool
- [x] T021 [US2] Implement GraphEdgePage dataclass in src/decisiongraph/query/graph.py:
  - edges: list[Edge]
  - next_cursor: Optional[GraphEdgeCursor]
- [x] T022 [US2] Implement get_context_subgraph(center, max_depth, filter) -> ContextSubgraph
- [x] T023 [US2] Implement list_node_edges(node, cursor, limit) -> GraphEdgePage
- [x] T024 [US2] Add TC-P5-007 (subgraph_depth_0_center_only) test
- [x] T025 [US2] Add TC-P5-008 (subgraph_filter_edge_node_type) test
- [x] T026 [US2] Add test for max_edges truncation

**Checkpoint**: Graph queries work

---

## Phase 5: User Story 3 - Find Precedents (Priority: P1)

**Goal**: Find similar past decisions for precedent citation

**Independent Test**: Query by policy_id and check results

### Implementation for User Story 3

- [x] T027 [US3] Implement PrecedentQuery dataclass in src/decisiongraph/query/precedents.py
- [x] T028 [US3] Implement PrecedentHit dataclass in src/decisiongraph/query/precedents.py
- [x] T029 [US3] Implement find_precedents(query) -> list[PrecedentHit]:
  - Only finished traces
  - Deduplicated by trace_id
  - Ordered by relevance/recency
- [x] T030 [US3] Add TC-P5-010 (precedent_search_by_policy) test
- [x] T031 [US3] Add TC-P5-011 (precedent_search_dedup_order) test
- [x] T032 [US3] Add test for entity filter
- [x] T033 [US3] Add test for unfinished traces excluded

**Checkpoint**: Precedent search works

---

## Phase 6: User Story 4 - Projection Staleness Check (Priority: P1)

**Goal**: Prevent reading stale projection data

**Independent Test**: Don't run projector and attempt query

### Implementation for User Story 4

- [x] T034 [US4] Implement staleness check in projection-backed queries:
  - Compare projector cursor vs event log last_log_seq
  - If behind, raise DG_ERR_PROJECTION_OUT_OF_DATE
- [x] T035 [US4] Ensure event-log-only queries bypass staleness check
- [x] T036 [US4] Add TC-P5-012 (projection_out_of_date_error) test
- [x] T037 [US4] Add test for staleness bypass on list_events
- [x] T038 [US4] Add test for staleness bypass on get_trace_events

**Checkpoint**: Staleness is enforced for projection queries

---

## Phase 7: User Story 5 - Paginate Node Edges (Priority: P2)

**Goal**: Paginated edges for incremental neighbor loading

**Independent Test**: Query with cursor and check next_cursor

### Implementation for User Story 5

- [x] T039 [US5] Implement cursor-based pagination in list_node_edges
- [x] T040 [US5] Add TC-P5-009 (node_edges_pagination_cursor) test
- [x] T041 [US5] Add test for limit enforcement
- [x] T042 [US5] Add test for last page (next_cursor=None)

**Checkpoint**: Pagination works for high-degree nodes

---

## Phase 8: API Integration

**Purpose**: Integrate queries into main DecisionGraph API

- [x] T043 Add query_trace(trace_id) method to src/decisiongraph/api.py
- [x] T044 Add query_graph(center, depth) method to src/decisiongraph/api.py
- [x] T045 Add find_precedents(query) method to src/decisiongraph/api.py
- [x] T046 Update src/decisiongraph/query/__init__.py with exports

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and integration

- [x] T047 Run all 12 P5 test cases and verify pass
- [x] T048 Verify query by trace_id returns in under 50ms for 10K events
- [x] T049 Verify subgraph query (depth=2) completes in under 200ms
- [x] T050 Verify precedent search returns in under 100ms for 1K traces
- [x] T051 Verify all queries return deterministic results
- [x] T052 Verify mypy strict passes on new code
- [x] T053 Verify ruff check passes on new code

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Depends on 001-004 being complete
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - US1, US2, US3 can run in parallel
  - US4 can run parallel after any US starts
  - US5 depends on US2 (uses list_node_edges)
- **API Integration (Phase 8)**: Depends on US1, US2, US3
- **Polish (Phase 9)**: Depends on all phases being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - Event queries
- **User Story 2 (P1)**: Can start after Foundational - Graph queries
- **User Story 3 (P1)**: Can start after Foundational - Precedent search
- **User Story 4 (P1)**: Can start after any US begins - Cross-cutting
- **User Story 5 (P2)**: Depends on US2 (extends list_node_edges)

### Parallel Opportunities

- T002, T003, T004 can run in parallel (test skeletons)
- T005, T006, T007 can run in parallel (filter types)
- US1, US2, US3 can run in parallel

---

## Parallel Example: User Stories

```bash
# Launch all P1 user stories together:
Task: "Implement get_trace_summary(trace_id) -> TraceSummary"
Task: "Implement get_context_subgraph(center, max_depth, filter)"
Task: "Implement find_precedents(query) -> list[PrecedentHit]"
```

---

## Implementation Strategy

### MVP First (User Story 1 + 3)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (Filter Types)
3. Complete Phase 3: User Story 1 (Trace Event Queries)
4. Complete Phase 5: User Story 3 (Precedent Search)
5. **STOP and VALIDATE**: Test trace queries and precedent search

### Incremental Delivery

1. Setup + Foundational -> Filter types ready
2. Add User Story 1 -> Trace queries work
3. Add User Story 2 -> Graph queries work
4. Add User Story 3 -> Precedent search works
5. Add User Story 4 -> Staleness enforced
6. Add User Story 5 -> Pagination works
7. API Integration -> Methods on DecisionGraph class
8. Polish phase -> All 12 test cases pass

---

## Summary

- **Total Tasks**: 53
- **Setup Phase**: 4 tasks
- **Foundational Phase**: 5 tasks
- **User Story 1**: 10 tasks
- **User Story 2**: 7 tasks
- **User Story 3**: 7 tasks
- **User Story 4**: 5 tasks
- **User Story 5**: 4 tasks
- **API Integration**: 4 tasks
- **Polish Phase**: 7 tasks

**Parallel Opportunities**: T002-T004, T005-T007, US1||US2||US3

**MVP Scope**: User Story 1 + 3 (Trace Queries + Precedent Search)

**Status**: ✅ ALL 53 TASKS COMPLETE
