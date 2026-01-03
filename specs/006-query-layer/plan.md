# Implementation Plan: Query Layer & Precedent Search

**Branch**: `006-query-layer` | **Date**: 2026-01-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/006-query-layer/spec.md`
**SSOT Phase**: P5 — Query Layer + Precedent Search v1

## Summary

Implement the query APIs for events, graph, and precedent search. All queries MUST be deterministic with specified ordering. Projection-backed queries MUST enforce staleness checks.

## Technical Context

**Language/Version**: Python 3.12+ (DD-003)
**Primary Dependencies**: None (stdlib only)
**Storage**: Via storage.interface (backend agnostic)
**Testing**: pytest
**Target Platform**: Cross-platform
**Project Type**: Single project with src-layout
**Performance Goals**: <50ms trace query, <200ms subgraph, <100ms precedent
**Constraints**: Typed methods only (no DSL), deterministic results
**Scale/Scope**: Event, graph, and precedent query APIs

## Constitution Check

*GATE: All checks pass - no violations*

| Principle | Status | Verification |
|-----------|--------|--------------|
| I. Append-Only SSOT | ✅ | Queries read-only, no mutations |
| II. Deterministic Replay | ✅ | Query results deterministic |
| III. Library-First | ✅ | Typed methods, no DSL/GraphQL |
| IV. Minimal Dependencies | ✅ | No query framework deps |
| V. Module Boundaries | ✅ | query/ uses storage.interface only |
| VI. Framework-Agnostic | ✅ | Generic query contracts |

## Project Structure

### Source Code

```text
src/decisiongraph/
  query/
    __init__.py
    filters.py           # EventFilter, GraphFilter
    events.py            # TraceSummary, get_trace_events
    graph.py             # NodeRef, ContextSubgraph, etc.
    precedents.py        # PrecedentQuery, PrecedentHit
  api.py                 # Add query methods to DecisionGraph class

tests/
  unit/
    test_query_filters.py
  integration/
    test_queries.py
    test_precedent_search.py
```

## Implementation Steps

### Phase 1: Filter Types

1. Implement `query/filters.py`:
   - `EventFilter` dataclass
   - `GraphFilter` dataclass
   - `GraphEdgeCursor` for pagination

### Phase 2: Event Queries

1. Implement `query/events.py`:
   - `TraceSummary` dataclass
   - `get_trace_summary(trace_id) -> TraceSummary`
   - `get_trace_events(trace_id, filter) -> list[StoredEvent]`
   - `list_events(filter) -> list[StoredEvent]`

### Phase 3: Graph Queries

1. Implement `query/graph.py`:
   - `NodeRef` dataclass
   - `ContextSubgraph` dataclass (nodes, edges, truncated flag)
   - `GraphEdgePage` dataclass (edges, next_cursor)
   - `get_context_subgraph(center, max_depth, filter) -> ContextSubgraph`
   - `list_node_edges(node, cursor, limit) -> GraphEdgePage`

### Phase 4: Precedent Search

1. Implement `query/precedents.py`:
   - `PrecedentQuery` dataclass
   - `PrecedentHit` dataclass
   - `find_precedents(query) -> list[PrecedentHit]`
   - Only finished traces in results
   - Deduplicated by trace_id

### Phase 5: Staleness Check

1. Implement staleness check:
   - Compare projector cursor vs event log last_log_seq
   - If behind, raise `DG_ERR_PROJECTION_OUT_OF_DATE`
   - Event-log-only queries bypass staleness check

### Phase 6: API Integration

1. Add query methods to `api.py`:
   - `DecisionGraph.query_trace(trace_id)`
   - `DecisionGraph.query_graph(center, depth)`
   - `DecisionGraph.find_precedents(query)`

### Phase 7: Tests

1. TC-P5-001 through TC-P5-012
2. Ordering tests
3. Staleness tests

## SSOT References

- Section 7.4: Query API
- Section 7.4.0: Query Types
- Section 7.4.1-7.4.5: Query methods
- Section 7.6: Precedent Search API
- Section 11.8-11.11: Code skeletons
