# API Overview

## Core Class

```python
from decisiongraph import DecisionGraph
```

### `DecisionGraph`

- `start_trace(...)`: start a decision trace
- `append_event(...)`: append any supported event type
- `finish_trace(...)`: end a trace with an outcome
- `get_trace_events(trace_id)`: list events
- `get_context_subgraph(node_type, node_id, max_depth=1)`: graph query
- `find_precedents(...)`: precedent search
- `sync_projections(batch_size=None)`: apply pending projection updates
- `replay_projections(batch_size=None)`: rebuild projections from scratch

## CLI

```bash
python -m decisiongraph replay <db>
python -m decisiongraph dump-trace <db> <trace_id>
python -m decisiongraph dump-trace <db> <trace_id> --include-payload
```

## Contract Reference

For v1 compatibility guarantees and change rules, see [V1.0 Scope and Contracts](v1-contracts.md).
