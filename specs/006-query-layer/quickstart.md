# Quickstart: Query Layer & Precedent Search

## Prerequisites

- 001-005 completed and installed

## Query Trace Events

```python
from decisiongraph import DecisionGraph

dg = DecisionGraph("decisiongraph.db")

# Get trace summary
summary = dg.get_trace_summary("b3b0a4a8-...")
print(f"Workflow: {summary.workflow}")
print(f"Title: {summary.title}")
print(f"Outcome: {summary.outcome}")

# Get trace events
events = dg.get_trace_events("b3b0a4a8-...")
for event in events:
    print(f"{event.trace_seq}: {event.event_type}")

# Paginate events
events = dg.get_trace_events("b3b0a4a8-...", since_trace_seq=5, limit=10)
```

## Query Graph

```python
from decisiongraph.query.graph import NodeRef, GraphFilter

# Get subgraph around a trace
center = NodeRef(node_type="trace", node_id="b3b0a4a8-...")
subgraph = dg.get_context_subgraph(center, max_depth=2)

print(f"Nodes: {len(subgraph.nodes)}")
print(f"Edges: {len(subgraph.edges)}")
print(f"Truncated: {subgraph.truncated}")

# Filter by edge types
filter = GraphFilter(edge_types=["trace_evaluated_policy", "trace_requested_exception"])
subgraph = dg.get_context_subgraph(center, max_depth=1, filter=filter)

# Paginate edges
page = dg.list_node_edges(center, direction="outgoing", limit=10)
for edge in page.edges:
    print(f"{edge.edge_type}: {edge.to_node_key}")

# Next page
if page.next_cursor:
    next_page = dg.list_node_edges(center, cursor=page.next_cursor, limit=10)
```

## Find Precedents

```python
from decisiongraph.query.precedents import PrecedentQuery

# Find by policy
query = PrecedentQuery(policy_id="renewal_discount_cap")
hits = dg.find_precedents(query)

for hit in hits:
    print(f"Trace: {hit.trace_id}")
    print(f"  Workflow: {hit.workflow}")
    print(f"  Outcome: {hit.outcome}")
    print(f"  Finished: {hit.finished_at}")

# Find by entity
query = PrecedentQuery(entity_type="Account", entity_id="ACC-123")
hits = dg.find_precedents(query)

# Find by outcome
query = PrecedentQuery(outcome="success", limit=50)
hits = dg.find_precedents(query)
```

## Staleness Handling

```python
from decisiongraph.errors import DecisionGraphError

try:
    subgraph = dg.get_context_subgraph(center)
except DecisionGraphError as e:
    if e.code == "DG_ERR_PROJECTION_OUT_OF_DATE":
        # Run projector to catch up
        dg.rebuild_projections()
        subgraph = dg.get_context_subgraph(center)
```

## Running Tests

```bash
pytest tests/unit/test_query_filters.py
pytest tests/integration/test_queries.py
pytest tests/integration/test_precedent_search.py
```

## Next Steps

After this phase, proceed to `007-e2e-integration` for:
- Golden fixtures
- E2E tests
- Documentation
