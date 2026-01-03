# Research: Query Layer & Precedent Search

**Date**: 2026-01-01
**Phase**: P5 — Query Layer + Precedent Search v1

## Overview

All technical decisions are frozen in SSOT. This document consolidates query API specifications.

## Query Types (SSOT 7.4.0)

### NodeRef

Reference to a graph node.

```python
@dataclass(frozen=True)
class NodeRef:
    node_type: str
    node_id: str
```

### EventFilter

Filter for event queries.

```python
@dataclass
class EventFilter:
    trace_id: str | None = None
    event_type: str | None = None
    since_log_seq: int | None = None
    until_log_seq: int | None = None
    since_trace_seq: int | None = None
    limit: int | None = None
```

### GraphFilter

Filter for graph queries.

```python
@dataclass
class GraphFilter:
    edge_types: list[str] | None = None
    node_types: list[str] | None = None
    max_depth: int = 1
    max_nodes: int = 100
    max_edges: int = 500
```

### GraphEdgeCursor

Pagination cursor for edge queries.

```python
@dataclass(frozen=True)
class GraphEdgeCursor:
    edge_key: str
    direction: Literal["outgoing", "incoming"]
```

## Query Methods (SSOT 7.4.1-7.4.5)

### get_trace_summary (7.4.1)

```python
def get_trace_summary(trace_id: str) -> TraceSummary:
    """Get trace metadata."""
    # Returns from dg_trace_summary
    # Raises DG_ERR_NOT_FOUND if missing
```

### get_trace_events (7.4.2)

```python
def get_trace_events(
    trace_id: str,
    since_trace_seq: int | None = None,
    limit: int | None = None
) -> list[StoredEvent]:
    """Get events for a trace, ordered by trace_seq."""
    # Pagination via since_trace_seq
    # Ordered by trace_seq ascending
```

### list_events (7.4.3)

```python
def list_events(
    since_log_seq: int | None = None,
    until_log_seq: int | None = None,
    event_type: str | None = None,
    limit: int | None = None
) -> list[StoredEvent]:
    """List events from global log, ordered by log_seq."""
    # Ordered by log_seq ascending
```

### get_context_subgraph (7.4.4)

```python
def get_context_subgraph(
    center: NodeRef,
    max_depth: int = 1,
    filter: GraphFilter | None = None
) -> ContextSubgraph:
    """Get scoped subgraph around center node."""
    # Returns nodes + edges within depth
    # Truncated flag if limits hit
```

### list_node_edges (7.4.5)

```python
def list_node_edges(
    node: NodeRef,
    direction: Literal["outgoing", "incoming", "both"] = "both",
    cursor: GraphEdgeCursor | None = None,
    limit: int = 100
) -> GraphEdgePage:
    """Paginate edges from/to a node."""
    # Returns edges + next_cursor
```

## Precedent Search (SSOT 7.6)

### PrecedentQuery

```python
@dataclass
class PrecedentQuery:
    policy_id: str | None = None
    policy_version: str | None = None
    entity_type: str | None = None
    entity_id: str | None = None
    outcome: str | None = None
    limit: int = 100
```

### PrecedentHit

```python
@dataclass(frozen=True)
class PrecedentHit:
    trace_id: str
    workflow: str
    title: str
    outcome: str
    policy_id: str | None
    finished_at: str
```

### find_precedents

```python
def find_precedents(query: PrecedentQuery) -> list[PrecedentHit]:
    """Find similar past decisions."""
    # Only finished traces
    # Deduplicated by trace_id
    # Ordered by finished_log_seq desc
```

## Staleness Check

Projection-backed queries MUST check staleness:

```python
def _check_staleness(self):
    projector_seq = self._projector.get_cursor()
    event_seq = self._store.get_last_log_seq()
    if projector_seq < event_seq:
        raise DecisionGraphError(
            "DG_ERR_PROJECTION_OUT_OF_DATE",
            f"Projections at {projector_seq}, events at {event_seq}"
        )
```

Applies to:
- `get_context_subgraph`
- `list_node_edges`
- `find_precedents`

Does NOT apply to:
- `get_trace_events` (event log only)
- `list_events` (event log only)

## Ordering Rules

| Query | Order By | Direction |
|-------|----------|-----------|
| get_trace_events | trace_seq | ASC |
| list_events | log_seq | ASC |
| get_context_subgraph.nodes | node_key | ASC |
| get_context_subgraph.edges | edge_key | ASC |
| list_node_edges | edge_key | ASC |
| find_precedents | finished_log_seq | DESC |

## Conclusion

All query semantics are specified in SSOT. No external research required.
