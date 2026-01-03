# Data Model: Projection Engine & Context Graph

**Date**: 2026-01-01
**Phase**: P3 — Projection Engine + Context Graph
**SSOT Reference**: Section 6.2

## Projection Tables

### dg_cg_nodes

Context graph nodes.

```python
@dataclass(frozen=True)
class GraphNode:
    node_key: str           # "trace:uuid" or "entity:Type:id"
    node_type: str          # trace, entity, input, policy, exception, action, actor
    node_id: str            # Identifier within type
    projection_version: int # Always 1 for now
    created_at_log_seq: int # log_seq that created this node
    attrs_json: str         # Always '{}' in v1
```

### dg_cg_edges

Context graph edges.

```python
@dataclass(frozen=True)
class GraphEdge:
    edge_key: str           # Unique edge identifier
    edge_type: str          # One of 9 edge types
    from_node_key: str      # Source node
    to_node_key: str        # Target node
    source_event_id: str    # Event that created this edge
    projection_version: int # Always 1
    created_at_log_seq: int # log_seq that created this edge
    attrs_json: str         # Always '{}' in v1
```

### dg_trace_summary

Trace metadata for explorer and search.

```python
@dataclass
class TraceSummary:
    trace_id: str
    workflow: str
    title: str
    primary_entity_type: str
    primary_entity_id: str
    started_at: str              # RFC3339
    finished_at: str | None      # RFC3339 or None if running
    outcome: str | None          # success/failure/abandoned or None
    started_log_seq: int
    finished_log_seq: int | None
```

### dg_precedent_index

Fast precedent lookup (only finished traces).

```python
@dataclass(frozen=True)
class PrecedentIndexRow:
    id: int                      # Auto-increment
    trace_id: str
    policy_id: str | None
    policy_version: str | None
    exception_id: str | None
    outcome: str                 # success/failure/abandoned
    finished_log_seq: int
```

### dg_projection_meta

Projection cursor tracking.

```python
@dataclass
class ProjectionMeta:
    projection_name: str         # "context_graph" or "precedent_index"
    projection_version: int      # Schema version
    last_applied_log_seq: int    # Cursor position
    updated_at: str              # RFC3339
```

## Node Types

| Type | Description | node_id Format |
|------|-------------|----------------|
| `trace` | Decision trace | `{trace_id}` |
| `entity` | Business entity | `{entity_type}:{entity_id}` |
| `input` | Observed input | `{input_id}` |
| `policy` | Evaluated policy | `{policy_id}:{policy_version}` |
| `exception` | Requested exception | `{exception_id}` |
| `action` | Proposed/committed action | `{action_id}` |
| `actor` | Approving actor | `{actor_type}:{actor_id}` |

## Edge Types

| Edge Type | From → To | Event Source |
|-----------|-----------|--------------|
| `trace_involves_entity` | trace → entity | EntityObserved |
| `trace_observed_input` | trace → input | InputObserved |
| `trace_evaluated_policy` | trace → policy | PolicyEvaluated |
| `trace_requested_exception` | trace → exception | ExceptionRequested |
| `exception_approved_by` | exception → actor | ApprovalRecorded |
| `trace_cited_precedent` | trace → trace | PrecedentCited |
| `trace_proposed_action` | trace → action | ActionProposed |
| `trace_committed_action` | trace → action | ActionCommitted |
| `action_targets_entity` | action → entity | ActionProposed |

## Projector Protocol

```python
class Projector(Protocol):
    def project_event(self, event: StoredEvent) -> None:
        """Project a single event into projections."""
        ...

    def rebuild(self) -> None:
        """Rebuild all projections from scratch."""
        ...

    def get_cursor(self) -> int:
        """Get last applied log_seq."""
        ...

    def compute_digest(self, projection: str) -> str:
        """Compute deterministic digest for projection."""
        ...
```

## Event → Projection Mapping

### TraceStarted
- Create `trace` node
- Create `dg_trace_summary` row

### InputObserved
- Create `input` node
- Create `trace_observed_input` edge

### EntityObserved
- Create/upsert `entity` node
- Create `trace_involves_entity` edge

### PolicyEvaluated
- Create `policy` node
- Create `trace_evaluated_policy` edge

### ExceptionRequested
- Create `exception` node
- Create `trace_requested_exception` edge

### ApprovalRecorded
- Create `actor` node
- Create `exception_approved_by` edge

### PrecedentCited
- Create `trace_cited_precedent` edge (to existing trace)

### ActionProposed
- Create `action` node
- Create `trace_proposed_action` edge
- Create `action_targets_entity` edge

### ActionCommitted
- Create `trace_committed_action` edge

### TraceFinished
- Update `dg_trace_summary` (finished_at, outcome)
- Create `dg_precedent_index` rows
