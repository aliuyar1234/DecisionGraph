# Query and Ordering Invariants

This document freezes the ordering guarantees that callers and future parity tests can rely on.

## Event-Log Queries

### `list_events()`

- ordered by `log_seq ASC`
- optional filters must not change deterministic ordering
- `since_log_seq` and `until_log_seq` are inclusive/exclusive exactly as implemented today

### `get_trace_events()`

- ordered by `trace_seq ASC`
- `since_trace_seq` filters to strictly later events
- missing traces raise not-found rather than returning an empty list

## Projection-Backed Queries

### Staleness Rule

Before returning projection-backed data, the reference implementation compares:

- projector cursor
- store `last_log_seq`

If the cursor is behind, the read fails as out-of-date.

This applies to:

- `get_trace_summary()`
- `get_context_subgraph()`
- `list_node_edges()`
- `find_precedents()`

## Trace Summary

`get_trace_summary()` returns exactly one summary row for a trace. There is no list ordering surface beyond the single-row lookup.

## Graph Query Ordering

- subgraph nodes are returned sorted by `node_id`
- subgraph edges are returned sorted by `edge_id`
- paginated edge lists are ordered by `log_seq ASC, edge_id ASC`

## Precedent Ordering

Frozen final ordering for precedent hits:

- most recent trace first via `last_log_seq DESC`
- deterministic tiebreak via `trace_id ASC`

## CLI JSON Stability

The read-only CLI JSON modes are also part of the deterministic surface:

- `dump-trace` emits events in trace order
- JSON object keys are emitted in sorted order
- `projection-status --include-digests` emits sorted top-level and digest keys
- repeated runs over unchanged data must produce byte-stable output
