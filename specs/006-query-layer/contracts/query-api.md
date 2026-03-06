# API Contract: Query Layer

**SSOT Reference**: Sections 7.4, 7.6

## get_trace_summary

Get trace metadata.

```python
def get_trace_summary(trace_id: str) -> TraceSummary
```

**Returns**: TraceSummary with workflow, title, outcome, timestamps

**Errors**:
- `DG_ERR_NOT_FOUND`: Trace doesn't exist
- `DG_ERR_PROJECTION_OUT_OF_DATE`: Projections behind event log

## get_trace_events

Get events for a trace.

```python
def get_trace_events(
    trace_id: str,
    since_trace_seq: int | None = None,
    limit: int | None = None
) -> list[StoredEvent]
```

**Order**: `trace_seq` ascending

**Errors**:
- `DG_ERR_NOT_FOUND`: Trace doesn't exist
- `DG_ERR_INVALID_ARGUMENT`: limit > 10000

## list_events

List events from global log.

```python
def list_events(
    since_log_seq: int | None = None,
    until_log_seq: int | None = None,
    event_type: str | None = None,
    limit: int | None = None
) -> list[StoredEvent]
```

**Order**: `log_seq` ascending

**Errors**:
- `DG_ERR_INVALID_ARGUMENT`: since > until or limit > 10000

## get_context_subgraph

Get scoped subgraph around center node.

```python
def get_context_subgraph(
    center: NodeRef,
    max_depth: int = 1,
    filter: GraphFilter | None = None
) -> ContextSubgraph
```

**Returns**: ContextSubgraph with:
- `nodes`: List of GraphNode, sorted by node_key
- `edges`: List of GraphEdge, sorted by edge_key
- `truncated`: True if max_nodes or max_edges hit

**Errors**:
- `DG_ERR_PROJECTION_OUT_OF_DATE`: Projections behind event log
- `DG_ERR_INVALID_ARGUMENT`: max_depth > 10

**Note**: Center node not found returns empty result (not error)

## list_node_edges

Paginate edges from/to a node.

```python
def list_node_edges(
    node: NodeRef,
    direction: Literal["outgoing", "incoming", "both"] = "both",
    cursor: GraphEdgeCursor | None = None,
    limit: int = 100
) -> GraphEdgePage
```

**Returns**: GraphEdgePage with:
- `edges`: List of GraphEdge
- `next_cursor`: For next page, or None if last page

**Order**: `edge_key` ascending

**Errors**:
- `DG_ERR_PROJECTION_OUT_OF_DATE`: Projections behind

## find_precedents

Find similar past decisions.

```python
def find_precedents(query: PrecedentQuery) -> list[PrecedentHit]
```

**Filters**:
- `policy_id`: Match policy
- `policy_version`: Match version (requires policy_id)
- `entity_type`: Match primary entity type
- `entity_id`: Match primary entity ID (requires entity_type)
- `outcome`: Match outcome

**Returns**: List of PrecedentHit, deduplicated by trace_id

**Order**: `finished_log_seq` descending (most recent first)

**Constraints**:
- Only finished traces included
- Max 1 hit per trace_id

**Errors**:
- `DG_ERR_PROJECTION_OUT_OF_DATE`: Projections behind
- `DG_ERR_INVALID_ARGUMENT`: limit > 10000

## Staleness Check Contract

For projection-backed queries:

```python
# Before query
projector_seq = projector.get_cursor()
event_seq = store.get_last_log_seq()

if projector_seq < event_seq:
    raise DecisionGraphError(
        "DG_ERR_PROJECTION_OUT_OF_DATE",
        f"Projections at log_seq={projector_seq}, events at {event_seq}"
    )
```

**Applies to**:
- get_trace_summary
- get_context_subgraph
- list_node_edges
- find_precedents

**Does NOT apply to**:
- get_trace_events (event log only)
- list_events (event log only)
