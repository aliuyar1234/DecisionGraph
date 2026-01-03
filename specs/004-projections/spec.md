# Feature Specification: Projection Engine & Context Graph

**Feature Branch**: `004-projections`
**Created**: 2026-01-01
**Status**: Draft
**SSOT Phase**: P3 — Projection Engine + Context Graph
**SSOT Reference**: `SPEC_v1.0.3-minpatch.md` Section 8.1 (P3)

## Overview

This specification covers the deterministic projection engine that transforms the append-only event log into queryable read models: Context Graph (nodes/edges) and Precedent Index (trace summaries). Projections MUST be reproducible via replay.

**SSOT Principle**: Projection schemas, replay algorithm, and digest computation are defined in SSOT Section 6.2. This spec references those sections.

---

## Constitution Check

| Principle | Applies | How Verified |
|-----------|---------|--------------|
| I. Append-Only SSOT | ✅ | Projections derived from events |
| II. Deterministic Replay | ✅ | Digest gate in CI (DD-013) |
| III. Library-First | ✅ | No UI deps, query contracts only |
| IV. Minimal Dependencies | ✅ | stdlib only for projector |
| V. Module Boundaries | ✅ | projections/ uses storage.interface only |
| VI. Framework-Agnostic | ✅ | No framework-specific projections |

**Key Constraints**:
- Projections MUST be rebuildable from events (Constitution I)
- Digest MUST NOT include wall-clock times (Constitution II)
- `attrs_json` MUST remain `{}` for digest stability (Constitution II, DD-019)
- Scoped subgraphs only, NO global graph queries (DD-017)
- Projector MUST be deterministic - same events = same digest (Constitution II)

---

## User Scenarios & Testing

### User Story 1 - Build Context Graph from Events (Priority: P1)

As an explorer user, I want events transformed into a graph so that I can visualize decision relationships.

**Why this priority**: Graph is the primary navigation structure for understanding decisions.

**Independent Test**: Can be verified by replaying events and checking node/edge counts.

**Acceptance Scenarios**:

1. **Given** a `TraceStarted` event, **When** projector runs, **Then** a `trace` node is created
2. **Given** an `EntityObserved` event, **When** projector runs, **Then** entity node + `trace_involves_entity` edge created
3. **Given** a `PolicyEvaluated` event, **When** projector runs, **Then** policy node + `trace_evaluated_policy` edge created

---

### User Story 2 - Deterministic Replay (Priority: P1)

As a system operator, I want projection rebuild to produce identical results so that I can verify data integrity.

**Why this priority**: Determinism is required for audit and consistency verification.

**Independent Test**: Can be verified by rebuilding projections twice and comparing digests.

**Acceptance Scenarios**:

1. **Given** the same event log, **When** I rebuild projections twice, **Then** digests are identical
2. **Given** projections exist, **When** new events arrive, **Then** projector resumes from `last_applied_log_seq`
3. **Given** projector encounters invalid `payload_hash`, **When** processing, **Then** `DG_ERR_CONFLICT` is raised

---

### User Story 3 - Trace Summary for Precedent Search (Priority: P1)

As an agent querying precedents, I want trace summaries so that I can find relevant past decisions quickly.

**Why this priority**: Precedent search depends on indexed trace metadata.

**Independent Test**: Can be verified by finishing a trace and checking `dg_trace_summary` table.

**Acceptance Scenarios**:

1. **Given** a `TraceStarted` event, **When** projector runs, **Then** `dg_trace_summary` row is created with workflow/title
2. **Given** a `TraceFinished` event, **When** projector runs, **Then** `finished_log_seq` and `outcome` are set
3. **Given** an unfinished trace, **When** I query trace summary, **Then** `outcome` is null

---

### User Story 4 - Precedent Index for Fast Lookup (Priority: P1)

As a precedent search user, I want indexed policy/exception data so that lookups don't scan the full graph.

**Why this priority**: Enterprise scale requires indexed queries, not graph traversal.

**Independent Test**: Can be verified by querying `dg_precedent_index` by policy_id.

**Acceptance Scenarios**:

1. **Given** a finished trace with `PolicyEvaluated`, **When** projector runs, **Then** `dg_precedent_index` row exists
2. **Given** a finished trace with `ExceptionRequested`, **When** projector runs, **Then** index row includes `exception_id`
3. **Given** an unfinished trace, **When** I query precedent index, **Then** no rows exist (only finished traces)

---

### User Story 5 - Digest Verification (Priority: P2)

As a CI operator, I want projection digests so that determinism is enforced in the build pipeline.

**Why this priority**: Determinism gate prevents regressions.

**Independent Test**: Can be verified by computing digest and comparing to golden fixture.

**Acceptance Scenarios**:

1. **Given** context_graph projection, **When** digest computed, **Then** matches expected SHA-256
2. **Given** precedent_index projection, **When** digest computed, **Then** matches expected SHA-256
3. **Given** different `recorded_at` times, **When** digests computed, **Then** digests are still identical (no wall-clock dependency)

---

### Edge Cases

- What happens when trace_seq has gaps? → `DG_ERR_EVENT_SEQUENCE_INVALID`
- What happens when projector is interrupted? → Resume from `last_applied_log_seq`
- What happens when projection version changes? → Full rebuild into shadow tables
- What happens when `attrs_json` is requested? → MUST be `{}` in v1

---

## Requirements

### Functional Requirements

- **FR-001**: Projector MUST process events ordered by `log_seq` → SSOT 6.2.5
- **FR-002**: Projector MUST update both `context_graph` and `precedent_index` atomically → SSOT 6.2.1
- **FR-003**: Node schema MUST match → SSOT 6.2.2
- **FR-004**: Edge schema MUST match → SSOT 6.2.3
- **FR-005**: Edge types MUST include all 9 types → SSOT 6.2.4
- **FR-006**: Digest MUST be SHA-256 over canonical JSON → SSOT 6.2.7
- **FR-007**: `attrs_json` MUST be `{}` for all nodes/edges in v1 → SSOT 6.2.2, 6.2.3
- **FR-008**: Precedent index rows MUST only exist for finished traces → SSOT 6.2.10
- **FR-009**: `action_targets_entity` edge MUST be deduplicated per (trace_id, action_id) → SSOT 6.2.4
- **FR-010**: Projector MUST NOT use wall-clock time → SSOT 6.2.5

### Key Entities

- **Projector**: Transforms events into projections
- **dg_cg_nodes**: Context graph nodes table (SSOT 6.2.2)
- **dg_cg_edges**: Context graph edges table (SSOT 6.2.3)
- **dg_trace_summary**: Trace metadata for explorer/search (SSOT 6.2.9)
- **dg_precedent_index**: Fast precedent lookup table (SSOT 6.2.10)
- **dg_projection_meta**: Tracks projection version and cursor (SSOT 6.2.6)

### Edge Types (SSOT 6.2.4)

1. `trace_involves_entity`
2. `trace_observed_input`
3. `trace_evaluated_policy`
4. `trace_requested_exception`
5. `exception_approved_by`
6. `trace_cited_precedent`
7. `trace_proposed_action`
8. `trace_committed_action`
9. `action_targets_entity`

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: Full replay of 10K events completes in under 30 seconds
- **SC-002**: Digest is stable across 100 replay runs
- **SC-003**: Incremental projection of 100 new events completes in under 1 second
- **SC-004**: All 13 test cases from SSOT P3 pass (TC-P3-001 through TC-P3-013)
- **SC-005**: Digest matches between SQLite and Postgres for identical events

### Test Cases (from SSOT 8.1)

| ID | Name | Description |
|----|------|-------------|
| TC-P3-001 | projector_full_replay_builds_graph | Full replay creates correct graph |
| TC-P3-002 | projector_digest_stable | Digest identical across rebuilds |
| TC-P3-003 | projector_resume_cursor | Resume from last_applied_log_seq |
| TC-P3-004 | projector_reject_bad_payload_hash | Invalid hash rejected |
| TC-P3-005 | projector_reject_trace_seq_gap | Sequence gaps rejected |
| TC-P3-006 | graph_nodes_keys | Node keys match SSOT format |
| TC-P3-007 | graph_edges_keys | Edge keys match SSOT format |
| TC-P3-008 | exception_pseudo_node_created | Exception nodes created |
| TC-P3-009 | action_pseudo_node_created | Action nodes created |
| TC-P3-010 | subgraph_ordering | Nodes/edges ordered correctly |
| TC-P3-011 | action_targets_entity_edge_required | Target edge exists |
| TC-P3-012 | digest_ignores_recorded_at | No wall-clock in digest |
| TC-P3-013 | projection_attrs_are_empty | attrs_json is {} |

---

## Dependencies & Constraints

### Depends On

- **001-foundation**: Error types
- **002-event-model**: EventEnvelope, StoredEvent
- **003-storage-sqlite**: SQLiteEventStore, projection tables

### Blocks

- 005-storage-postgres (P4) - needs digest parity tests
- 006-query-layer (P5) - needs graph to query

### Frozen Decisions

- **DD-010**: Relational projection tables + deterministic replay
- **DD-013**: Replay digest gate + golden tests
- **DD-017**: Scoped subgraphs, no global hairball
- **DD-019**: Trace summary from precedent_index projection

---

## Files to Implement

```
src/decisiongraph/
  projections/
    __init__.py
    interfaces.py        # Projector protocol
    projector.py         # Main projector implementation
    context_graph.py     # Node/edge emission logic
    digests.py           # Digest computation
  storage/
    sqlite/
      migrations/
        0002_projections.sql  # Projection tables
tests/
  unit/
    test_projector.py
    test_digests.py
  integration/
    test_projection_replay.py
```

---

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
- DD-010, DD-013, DD-017, DD-019: Frozen decisions
