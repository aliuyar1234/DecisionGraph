# API Contract: Projector

**SSOT Reference**: Section 6.2

## Protocol Definition

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

## project_event

Project a single event into all projections.

**Input**: `StoredEvent`
**Output**: None (side effect: projection tables updated)

**Behavior**:
1. Check event is next in sequence (log_seq > cursor)
2. Create nodes per event type
3. Create edges per event type
4. Update trace summary if applicable
5. Update precedent index if TraceFinished
6. Update cursor

**Errors**:
- `DG_ERR_CONFLICT`: Invalid payload_hash
- `DG_ERR_EVENT_SEQUENCE_INVALID`: trace_seq gap

## rebuild

Rebuild all projections from scratch.

**Behavior**:
1. Clear all projection tables
2. Reset cursor to 0
3. Process all events in log_seq order
4. Update cursor after each event

## get_cursor

Get current projection position.

**Output**: `int` - last applied log_seq (0 if empty)

## compute_digest

Compute deterministic digest for a projection.

**Input**: `projection` - "context_graph" or "precedent_index"
**Output**: `str` - "sha256:..." hash

**Context Graph Digest**:
```python
{
    "nodes": [
        {"node_key": "...", "node_type": "...", "node_id": "..."},
        ...
    ],
    "edges": [
        {"edge_key": "...", "edge_type": "...", "from_node_key": "...", "to_node_key": "..."},
        ...
    ]
}
```
- Nodes sorted by `node_key`
- Edges sorted by `edge_key`
- Canonical JSON → SHA-256

**Precedent Index Digest**:
```python
{
    "summaries": [...],  # Sorted by trace_id
    "precedents": [...]  # Sorted by (trace_id, policy_id)
}
```

## Node Creation Rules

| Event | Node Type | node_id |
|-------|-----------|---------|
| TraceStarted | trace | trace_id |
| InputObserved | input | input_id |
| EntityObserved | entity | {entity_type}:{entity_id} |
| PolicyEvaluated | policy | {policy_id}:{policy_version} |
| ExceptionRequested | exception | exception_id |
| ActionProposed | action | action_id |
| ApprovalRecorded | actor | {actor_type}:{actor_id} |

## Edge Creation Rules

| Event | Edge Type | From → To |
|-------|-----------|-----------|
| InputObserved | trace_observed_input | trace → input |
| EntityObserved | trace_involves_entity | trace → entity |
| PolicyEvaluated | trace_evaluated_policy | trace → policy |
| ExceptionRequested | trace_requested_exception | trace → exception |
| ApprovalRecorded | exception_approved_by | exception → actor |
| PrecedentCited | trace_cited_precedent | trace → cited_trace |
| ActionProposed | trace_proposed_action | trace → action |
| ActionProposed | action_targets_entity | action → entity |
| ActionCommitted | trace_committed_action | trace → action |

## Determinism Requirements

1. Process events in strict log_seq order
2. Node/edge creation is deterministic (same event → same nodes/edges)
3. No wall-clock timestamps in digest computation
4. `attrs_json` MUST be `{}` always
5. Same events → identical digest (cross-backend)
