# Research: Projection Engine & Context Graph

**Date**: 2026-01-01
**Phase**: P3 — Projection Engine + Context Graph

## Overview

All technical decisions are frozen in SSOT. This document consolidates the relevant specifications.

## Projection Algorithm (SSOT 6.2.5)

### Processing Order

Events MUST be processed in `log_seq` order:

```python
def rebuild(self):
    for event in store.list_events(since_log_seq=cursor):
        self.project_event(event)
        self.update_cursor(event.log_seq)
```

### Cursor Management

Track progress in `dg_projection_meta`:
- Resume from `last_applied_log_seq` on restart
- Update cursor after each event (or batch)
- Atomic update with projection changes

## Node Schema (SSOT 6.2.2)

### Node Key Format

```
{node_type}:{node_id}
```

Examples:
- `trace:b3b0a4a8-2a2f-4bdf-b9ce-6a4bbf3aa2c4`
- `entity:Account:ACC-123`
- `policy:renewal_discount_cap:3.2`
- `exception:EXC-001`
- `action:ACT-001`

### Node Types

| Type | Created From | node_id Format |
|------|--------------|----------------|
| trace | TraceStarted | trace_id |
| entity | EntityObserved | {entity_type}:{entity_id} |
| input | InputObserved | input_id |
| policy | PolicyEvaluated | {policy_id}:{policy_version} |
| exception | ExceptionRequested | exception_id |
| action | ActionProposed | action_id |
| actor | ApprovalRecorded.approver | {actor_type}:{actor_id} |

### Node Table Row

```python
@dataclass
class GraphNode:
    node_key: str           # Primary key
    node_type: str
    node_id: str
    projection_version: int # Always 1
    created_at_log_seq: int
    attrs_json: str         # Always '{}'
```

## Edge Schema (SSOT 6.2.3)

### Edge Key Format

```
{edge_type}:{from_node_key}:{to_node_key}:{source_event_id}
```

### Edge Table Row

```python
@dataclass
class GraphEdge:
    edge_key: str
    edge_type: str
    from_node_key: str
    to_node_key: str
    source_event_id: str
    projection_version: int
    created_at_log_seq: int
    attrs_json: str  # Always '{}'
```

## Edge Types (SSOT 6.2.4)

| Edge Type | From | To | Created By |
|-----------|------|-----|------------|
| trace_involves_entity | trace | entity | EntityObserved |
| trace_observed_input | trace | input | InputObserved |
| trace_evaluated_policy | trace | policy | PolicyEvaluated |
| trace_requested_exception | trace | exception | ExceptionRequested |
| exception_approved_by | exception | actor | ApprovalRecorded |
| trace_cited_precedent | trace | trace | PrecedentCited |
| trace_proposed_action | trace | action | ActionProposed |
| trace_committed_action | trace | action | ActionCommitted |
| action_targets_entity | action | entity | ActionProposed |

## Digest Computation (SSOT 6.2.7)

### Context Graph Digest

```python
def compute_context_graph_digest() -> str:
    # 1. Query all nodes ordered by node_key
    nodes = db.execute(
        "SELECT node_key, node_type, node_id, projection_version "
        "FROM dg_cg_nodes ORDER BY node_key"
    )

    # 2. Query all edges ordered by edge_key
    edges = db.execute(
        "SELECT edge_key, edge_type, from_node_key, to_node_key "
        "FROM dg_cg_edges ORDER BY edge_key"
    )

    # 3. Canonical JSON
    data = {
        "nodes": [row_to_dict(n) for n in nodes],
        "edges": [row_to_dict(e) for e in edges]
    }
    canonical = canonicalize_json(data)

    # 4. SHA-256
    return sha256_prefixed(canonical.encode())
```

### Excluded Fields

- `created_at_log_seq`: Depends on insertion order, not content
- `attrs_json`: Always `{}` so deterministic

### Precedent Index Digest

Similar approach over `dg_trace_summary` and `dg_precedent_index`.

## Trace Summary (SSOT 6.2.9)

### Creation (TraceStarted)

```python
def on_trace_started(event):
    insert("dg_trace_summary", {
        "trace_id": event.trace_id,
        "workflow": payload["workflow"],
        "title": payload["title"],
        "primary_entity_type": payload["primary_entity"]["entity_type"],
        "primary_entity_id": payload["primary_entity"]["entity_id"],
        "started_at": event.occurred_at,
        "started_log_seq": event.log_seq,
    })
```

### Completion (TraceFinished)

```python
def on_trace_finished(event):
    update("dg_trace_summary", {
        "finished_at": event.occurred_at,
        "outcome": payload["outcome"],
        "finished_log_seq": event.log_seq,
    }, where={"trace_id": event.trace_id})
```

## Precedent Index (SSOT 6.2.10)

Only created for **finished** traces:

```python
def on_trace_finished(event):
    # Get all PolicyEvaluated and ExceptionRequested for this trace
    for policy_event in get_trace_events(event.trace_id, type="PolicyEvaluated"):
        insert("dg_precedent_index", {
            "trace_id": event.trace_id,
            "policy_id": policy_event.payload["policy"]["policy_id"],
            "policy_version": policy_event.payload["policy"]["policy_version"],
            "outcome": payload["outcome"],
            "finished_log_seq": event.log_seq,
        })
```

## Conclusion

All technical details are specified in SSOT. No external research required.
