# Quickstart: Projection Engine & Context Graph

## Prerequisites

- 001-foundation completed
- 002-event-model completed
- 003-storage-sqlite completed

## Basic Usage

```python
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.projections import Projector

# Create store and projector
store = SQLiteEventStore("decisiongraph.db")
projector = Projector(store)

# Process new events
cursor = projector.get_cursor()
events = store.list_events(since_log_seq=cursor)
for event in events:
    projector.project_event(event)

# Or rebuild from scratch
projector.rebuild()
```

## Compute Digests

```python
# Get deterministic digest for verification
graph_digest = projector.compute_digest("context_graph")
print(f"Context Graph: {graph_digest}")

index_digest = projector.compute_digest("precedent_index")
print(f"Precedent Index: {index_digest}")
```

## Query Projections

```python
import sqlite3

conn = sqlite3.connect("decisiongraph.db")

# Get nodes for a trace
nodes = conn.execute("""
    SELECT node_key, node_type, node_id
    FROM dg_cg_nodes
    WHERE node_key LIKE 'trace:%'
""").fetchall()

# Get edges from a trace
edges = conn.execute("""
    SELECT edge_type, to_node_key
    FROM dg_cg_edges
    WHERE from_node_key = ?
""", ("trace:b3b0a4a8-...",)).fetchall()

# Get trace summary
summary = conn.execute("""
    SELECT workflow, title, outcome, finished_at
    FROM dg_trace_summary
    WHERE trace_id = ?
""", ("b3b0a4a8-...",)).fetchone()
```

## Verify Determinism

```python
# Rebuild twice and compare digests
projector.rebuild()
digest1 = projector.compute_digest("context_graph")

projector.rebuild()
digest2 = projector.compute_digest("context_graph")

assert digest1 == digest2, "Digest must be stable!"
```

## Node Key Examples

```python
# Trace node
"trace:b3b0a4a8-2a2f-4bdf-b9ce-6a4bbf3aa2c4"

# Entity node
"entity:Account:ACC-123"

# Policy node
"policy:renewal_discount_cap:3.2"

# Exception node
"exception:EXC-001"

# Action node
"action:ACT-001"
```

## Edge Key Examples

```python
# Format: {edge_type}:{from}:{to}:{event_id}
"trace_involves_entity:trace:b3b0...:entity:Account:ACC-123:event-id-1"
"trace_evaluated_policy:trace:b3b0...:policy:renewal_discount_cap:3.2:event-id-2"
```

## Running Tests

```bash
# Run projector tests
pytest tests/unit/test_projector.py
pytest tests/unit/test_digests.py

# Run replay tests
pytest tests/integration/test_projection_replay.py
```

## Next Steps

After this phase, proceed to `005-storage-postgres` for:
- Postgres backend with same schema
- Digest parity tests (SQLite vs Postgres)
