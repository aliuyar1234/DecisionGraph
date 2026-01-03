# Implementation Plan: Projection Engine & Context Graph

**Branch**: `004-projections` | **Date**: 2026-01-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-projections/spec.md`
**SSOT Phase**: P3 — Projection Engine + Context Graph

## Summary

Implement the deterministic projection engine that transforms the append-only event log into queryable read models: Context Graph (nodes/edges) and Precedent Index (trace summaries). Projections MUST be reproducible via replay with stable digests.

## Technical Context

**Language/Version**: Python 3.12+ (DD-003)
**Primary Dependencies**: None (stdlib only)
**Storage**: SQLite projection tables (via 003)
**Testing**: pytest with golden fixtures
**Target Platform**: Cross-platform
**Project Type**: Single project with src-layout
**Performance Goals**: 10K events in <30s, digest stable across rebuilds
**Constraints**: No wall-clock in digests, attrs_json = {}
**Scale/Scope**: Context Graph + Precedent Index projections

## Constitution Check

*GATE: All checks pass - no violations*

| Principle | Status | Verification |
|-----------|--------|--------------|
| I. Append-Only SSOT | ✅ | Projections derived from events |
| II. Deterministic Replay | ✅ | Digest gate in CI (DD-013) |
| III. Library-First | ✅ | No UI deps, query contracts only |
| IV. Minimal Dependencies | ✅ | stdlib only for projector |
| V. Module Boundaries | ✅ | projections/ uses storage.interface only |
| VI. Framework-Agnostic | ✅ | No framework-specific projections |

## Project Structure

### Documentation (this feature)

```text
specs/004-projections/
├── spec.md
├── plan.md              # This file
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
└── checklists/
```

### Source Code (repository root)

```text
src/decisiongraph/
  projections/
    __init__.py
    interfaces.py        # Projector protocol
    projector.py         # Main projector implementation
    context_graph.py     # Node/edge emission logic
    digests.py           # Digest computation

tests/
  unit/
    test_projector.py
    test_digests.py
  integration/
    test_projection_replay.py
```

**Structure Decision**: Extends 001-003 structure per SSOT 5.2

## Implementation Steps

### Phase 1: Projector Protocol

1. Define `Projector` protocol in `interfaces.py`:
   - `project_event(event: StoredEvent) -> None`
   - `rebuild() -> None`
   - `get_cursor() -> int` (last_applied_log_seq)

### Phase 2: Context Graph Emission

1. Implement `context_graph.py`:
   - Node creation for each event type
   - Edge creation per SSOT 6.2.4
   - Node key format: `{node_type}:{node_id}`
   - Edge key format: `{edge_type}:{from_key}:{to_key}:{event_id}`

2. Node types:
   - `trace`, `entity`, `input`, `policy`, `exception`, `action`, `actor`

3. Edge types (9):
   - `trace_involves_entity`
   - `trace_observed_input`
   - `trace_evaluated_policy`
   - `trace_requested_exception`
   - `exception_approved_by`
   - `trace_cited_precedent`
   - `trace_proposed_action`
   - `trace_committed_action`
   - `action_targets_entity`

### Phase 3: Trace Summary & Precedent Index

1. Update `dg_trace_summary` on:
   - `TraceStarted`: Create row
   - `TraceFinished`: Set finished_at, outcome

2. Update `dg_precedent_index` on:
   - `TraceFinished`: Create rows for each PolicyEvaluated/ExceptionRequested

### Phase 4: Digest Computation

1. Implement `digests.py`:
   - `compute_context_graph_digest() -> str`
   - `compute_precedent_index_digest() -> str`
   - Canonical JSON over sorted rows
   - SHA-256 hash

2. Digest rules:
   - Exclude `recorded_at` (wall-clock)
   - `attrs_json` MUST be `{}`
   - Sort by deterministic key

### Phase 5: Main Projector

1. Implement `projector.py`:
   - Process events in log_seq order
   - Update both projections atomically
   - Track cursor in `dg_projection_meta`
   - Resume from cursor on restart

### Phase 6: Tests

1. TC-P3-001 through TC-P3-013
2. Digest stability tests
3. Rebuild/replay tests

## SSOT References

- Section 6.2: Projections / Context Graph
- Section 6.2.1: Projection Set (v1)
- Section 6.2.2: Node Schema
- Section 6.2.3: Edge Schema
- Section 6.2.4: Edge Types
- Section 6.2.5: Replay Algorithm
- Section 6.2.7: Deterministic Digest
- Section 6.2.9: Trace Summary Projection
- Section 6.2.10: Precedent Index Projection
