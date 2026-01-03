# Feature Specification: Query Layer & Precedent Search

**Feature Branch**: `006-query-layer`
**Created**: 2026-01-01
**Status**: Draft
**SSOT Phase**: P5 — Query Layer + Precedent Search v1
**SSOT Reference**: `SPEC_v1.0.3-minpatch.md` Section 8.1 (P5)

## Overview

This specification covers the query APIs for events, graph, and precedent search. All queries MUST be deterministic with specified ordering. Projection-backed queries MUST enforce staleness checks.

**SSOT Principle**: Query signatures, filter schemas, and response types are defined in SSOT Sections 7.4 and 7.6.

---

## Constitution Check

| Principle | Applies | How Verified |
|-----------|---------|--------------|
| I. Append-Only SSOT | ✅ | Queries read-only, no mutations |
| II. Deterministic Replay | ✅ | Query results deterministic |
| III. Library-First | ✅ | Typed methods, no DSL/GraphQL |
| IV. Minimal Dependencies | ✅ | No query framework deps |
| V. Module Boundaries | ✅ | query/ uses storage.interface only |
| VI. Framework-Agnostic | ✅ | Generic query contracts |

**Key Constraints**:
- Queries MUST use typed Python methods, NOT SQL/GraphQL DSL (Constitution III, DD-011)
- Query results MUST be deterministic for identical input (Constitution II)
- query/ MUST NOT import concrete backends (Constitution V)
- Subgraph queries MUST be scoped, NO global hairball (DD-017)

---

## User Scenarios & Testing

### User Story 1 - Query Trace Events (Priority: P1)

As a trace investigator, I want to retrieve events for a trace so that I can understand what happened.

**Why this priority**: Event retrieval is the most basic query operation.

**Independent Test**: Can be verified by storing events and querying by trace_id.

**Acceptance Scenarios**:

1. **Given** a trace with events, **When** I call `get_trace_events(trace_id)`, **Then** events are returned in trace_seq order
2. **Given** pagination params, **When** I call with `since_trace_seq` and `limit`, **Then** only matching events returned
3. **Given** a non-existent trace_id, **When** I query, **Then** `DG_ERR_NOT_FOUND` is raised

---

### User Story 2 - Query Context Subgraph (Priority: P1)

As an explorer user, I want to query a scoped subgraph so that I can navigate decision relationships.

**Why this priority**: Graph exploration is primary for understanding decisions.

**Independent Test**: Can be verified by querying around a trace node with depth=1.

**Acceptance Scenarios**:

1. **Given** a center node, **When** I call `get_context_subgraph(center, max_depth=1)`, **Then** direct neighbors are returned
2. **Given** filter for edge_types, **When** I query, **Then** only matching edges included
3. **Given** max_edges limit reached, **When** I query, **Then** `truncated=True` in response

---

### User Story 3 - Find Precedents (Priority: P1)

As an agent making a decision, I want to find similar past decisions so that I can cite precedent.

**Why this priority**: Precedent search is core to decision-time retrieval value proposition.

**Independent Test**: Can be verified by querying by policy_id and checking results.

**Acceptance Scenarios**:

1. **Given** finished traces with PolicyEvaluated, **When** I query by policy_id, **Then** matching traces returned
2. **Given** query with entity filter, **When** I query, **Then** only traces with that primary entity returned
3. **Given** unfinished traces, **When** I query precedents, **Then** they are excluded

---

### User Story 4 - Projection Staleness Check (Priority: P1)

As a consistent reader, I want staleness checks so that I don't read stale data.

**Why this priority**: Consistency is required for decision-time retrieval.

**Independent Test**: Can be verified by not running projector and attempting query.

**Acceptance Scenarios**:

1. **Given** projections behind event log, **When** I query graph, **Then** `DG_ERR_PROJECTION_OUT_OF_DATE` raised
2. **Given** projections current, **When** I query, **Then** results returned normally
3. **Given** event-log-only query (list_events), **When** projections stale, **Then** query still succeeds

---

### User Story 5 - Paginate Node Edges (Priority: P2)

As an explorer expanding a node, I want paginated edges so that I can incrementally load neighbors.

**Why this priority**: Pagination prevents UI overload on high-degree nodes.

**Independent Test**: Can be verified by querying with cursor and checking next_cursor.

**Acceptance Scenarios**:

1. **Given** a node with many edges, **When** I query with `limit=10`, **Then** 10 edges + next_cursor returned
2. **Given** next_cursor, **When** I query again, **Then** next page of edges returned
3. **Given** last page, **When** I query, **Then** `next_cursor=None`

---

### Edge Cases

- What happens when since_log_seq > until_log_seq? → `DG_ERR_INVALID_ARGUMENT`
- What happens when limit > 10000? → `DG_ERR_INVALID_ARGUMENT`
- What happens when center node doesn't exist? → Empty result (not error)

---

## Requirements

### Functional Requirements

- **FR-001**: `get_trace_summary` MUST return TraceSummary → SSOT 7.4.1
- **FR-002**: `get_trace_events` MUST paginate by trace_seq → SSOT 7.4.2
- **FR-003**: `list_events` MUST order by log_seq → SSOT 7.4.3
- **FR-004**: `get_context_subgraph` MUST enforce max_depth, max_nodes, max_edges → SSOT 7.4.4
- **FR-005**: `list_node_edges` MUST paginate by cursor → SSOT 7.4.5
- **FR-006**: `find_precedents` MUST only include finished traces → SSOT 7.6.1
- **FR-007**: Precedent results MUST be deduplicated per trace_id → SSOT 7.6.1
- **FR-008**: Projection-backed queries MUST check staleness → SSOT 7.4
- **FR-009**: GraphFilter semantics MUST match → SSOT 7.4.0
- **FR-010**: Ordering MUST be deterministic for all queries → SSOT 7.4

### Key Entities (from SSOT 7.4.0)

- **NodeRef**: Reference to a graph node (node_type, node_id)
- **EventFilter**: Filter for event queries
- **GraphFilter**: Filter for graph queries
- **GraphEdgeCursor**: Pagination cursor for edge queries
- **ContextSubgraph**: Scoped graph result with truncation flag
- **GraphEdgePage**: Paginated edge result
- **TraceSummary**: Trace metadata
- **PrecedentQuery**: Filter for precedent search
- **PrecedentHit**: Precedent search result

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: Query by trace_id returns in under 50ms for 10K events
- **SC-002**: Subgraph query (depth=2) completes in under 200ms
- **SC-003**: Precedent search returns in under 100ms for 1K traces
- **SC-004**: All 12 test cases from SSOT P5 pass (TC-P5-001 through TC-P5-012)
- **SC-005**: All queries return deterministic results for identical input

### Test Cases (from SSOT 8.1)

| ID | Name | Description |
|----|------|-------------|
| TC-P5-001 | list_events_by_type | Filter by event_type works |
| TC-P5-002 | list_events_by_trace | Filter by trace_id works |
| TC-P5-003 | list_events_by_log_seq_range | Range filter works |
| TC-P5-004 | trace_summary_unfinished | Unfinished trace has null outcome |
| TC-P5-005 | trace_summary_finished | Finished trace has outcome |
| TC-P5-006 | trace_events_pagination | Pagination works correctly |
| TC-P5-007 | subgraph_depth_0_center_only | Depth 0 returns center only |
| TC-P5-008 | subgraph_filter_edge_node_type | Filters work |
| TC-P5-009 | node_edges_pagination_cursor | Cursor pagination works |
| TC-P5-010 | precedent_search_by_policy | Policy filter works |
| TC-P5-011 | precedent_search_dedup_order | Dedup and ordering correct |
| TC-P5-012 | projection_out_of_date_error | Staleness check works |

---

## Dependencies & Constraints

### Depends On

- **001-foundation**: Error types, domain types
- **002-event-model**: EventStore protocol
- **004-projections**: Projection tables, TraceSummary, PrecedentIndex

### Blocks

- 007-e2e-integration (P6)

---

## Files to Implement

```
src/decisiongraph/
  query/
    __init__.py
    filters.py           # EventFilter, GraphFilter (SSOT 11.8)
    events.py            # TraceSummary, get_trace_events (SSOT 11.9)
    graph.py             # NodeRef, ContextSubgraph, etc. (SSOT 11.10)
    precedents.py        # PrecedentQuery, PrecedentHit (SSOT 11.11)
  api.py                 # Add query methods to DecisionGraph class
tests/
  unit/
    test_query_filters.py
  integration/
    test_queries.py
    test_precedent_search.py
```

---

## SSOT References

- Section 7.4: Query API
- Section 7.4.0: Query Types
- Section 7.4.1-7.4.5: Query methods
- Section 7.6: Precedent Search API
- Section 11.8-11.11: Code skeletons
