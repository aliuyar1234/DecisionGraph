# Data Model: Query Layer & Precedent Search

**Date**: 2026-01-01
**Phase**: P5 — Query Layer + Precedent Search v1
**SSOT Reference**: Sections 7.4, 7.6, 11.8-11.11

## Filter Types

### EventFilter

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

```python
@dataclass
class GraphFilter:
    edge_types: list[str] | None = None
    node_types: list[str] | None = None
    max_depth: int = 1
    max_nodes: int = 100
    max_edges: int = 500
```

## Reference Types

### NodeRef

```python
@dataclass(frozen=True)
class NodeRef:
    node_type: str
    node_id: str

    @property
    def node_key(self) -> str:
        return f"{self.node_type}:{self.node_id}"
```

### GraphEdgeCursor

```python
@dataclass(frozen=True)
class GraphEdgeCursor:
    edge_key: str
    direction: Literal["outgoing", "incoming"]
```

## Result Types

### TraceSummary

```python
@dataclass(frozen=True)
class TraceSummary:
    trace_id: str
    workflow: str
    title: str
    primary_entity_type: str
    primary_entity_id: str
    started_at: str
    finished_at: str | None
    outcome: str | None
```

### ContextSubgraph

```python
@dataclass(frozen=True)
class ContextSubgraph:
    center: NodeRef
    nodes: list[GraphNode]
    edges: list[GraphEdge]
    truncated: bool
```

### GraphEdgePage

```python
@dataclass(frozen=True)
class GraphEdgePage:
    edges: list[GraphEdge]
    next_cursor: GraphEdgeCursor | None
```

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
    policy_version: str | None
    finished_at: str
```

## Query Interface

```python
class QueryAPI(Protocol):
    def get_trace_summary(self, trace_id: str) -> TraceSummary:
        """Get trace metadata."""
        ...

    def get_trace_events(
        self,
        trace_id: str,
        since_trace_seq: int | None = None,
        limit: int | None = None
    ) -> list[StoredEvent]:
        """Get events for a trace."""
        ...

    def list_events(
        self,
        since_log_seq: int | None = None,
        until_log_seq: int | None = None,
        event_type: str | None = None,
        limit: int | None = None
    ) -> list[StoredEvent]:
        """List events from global log."""
        ...

    def get_context_subgraph(
        self,
        center: NodeRef,
        max_depth: int = 1,
        filter: GraphFilter | None = None
    ) -> ContextSubgraph:
        """Get scoped subgraph."""
        ...

    def list_node_edges(
        self,
        node: NodeRef,
        direction: Literal["outgoing", "incoming", "both"] = "both",
        cursor: GraphEdgeCursor | None = None,
        limit: int = 100
    ) -> GraphEdgePage:
        """Paginate edges for a node."""
        ...

    def find_precedents(self, query: PrecedentQuery) -> list[PrecedentHit]:
        """Find similar past decisions."""
        ...
```

## Error Conditions

| Condition | Error Code |
|-----------|------------|
| Trace not found | DG_ERR_NOT_FOUND |
| since_log_seq > until_log_seq | DG_ERR_INVALID_ARGUMENT |
| limit > 10000 | DG_ERR_INVALID_ARGUMENT |
| Projections stale | DG_ERR_PROJECTION_OUT_OF_DATE |
| Center node missing | Empty result (not error) |
