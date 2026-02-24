# API Overview

## Core class

```python
from decisiongraph import DecisionGraph
```

### `DecisionGraph`

- `start_trace(...)` → start a decision trace
- `append_event(...)` → append any supported event type
- `finish_trace(...)` → end a trace with an outcome
- `get_trace_events(trace_id)` → list events
- `get_context_subgraph(node_type, node_id, max_depth=1)` → graph query
- `find_precedents(...)` → precedent search

## CLI

```bash
python -m decisiongraph replay <db>
python -m decisiongraph dump-trace <db> <trace_id>
python -m decisiongraph dump-trace <db> <trace_id> --include-payload
```
