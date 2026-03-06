# Projection and Replay Semantics

This document freezes how the reference projector turns the append-only log into queryable state.

## Projection Tables

The reference projector maintains:

- `dg_cg_nodes`
- `dg_cg_edges`
- `dg_trace_summary`
- `dg_policy_eval_index`
- `dg_precedent_index`
- `dg_projection_meta`

## Projection Cursor

The cursor is stored in `dg_projection_meta.last_processed_log_seq` for the `context_graph` projection name.

Frozen behavior:

- cursor starts at `0`
- cursor advances only after a projected event succeeds
- rollback restores the previous cursor
- projection-backed queries reject reads when cursor is behind the store’s `last_log_seq`

## Replay Order

- replay happens in global `log_seq` order
- per-trace monotonic `trace_seq` is revalidated during replay
- payload hash is revalidated during replay
- replay failure rolls back the active transaction or batch

## Rebuild Semantics

`rebuild()` clears all projection tables and resets:

- graph nodes
- graph edges
- precedent index
- policy evaluation index
- trace summary
- projection cursor

It does not mutate the event log.

## Event-Specific Projection Effects

- `TraceStarted`: seeds `dg_trace_summary` and trace graph nodes
- `PolicyEvaluated`: appends a `dg_policy_eval_index` row
- `TraceFinished`: updates `dg_trace_summary.outcome`, `finished_at`, `last_log_seq`, and rebuilds `dg_precedent_index` for the finished trace

## Precedent Index Build Rule

When a trace finishes, the projector scans that trace’s events in `trace_seq` order and materializes precedent rows from:

- each `PolicyEvaluated`
- each `ExceptionRequested`

The index row carries the trace’s primary entity information from `TraceStarted` when available.

## Graph-Specific Notes

- graph nodes and edges are stored with deterministic IDs
- placeholder nodes are created for externally referenced nodes, such as cited trace IDs
- `TraceFinished` itself does not add graph nodes or edges

## Batching

Batch projection is semantically equivalent to single-event projection:

- order remains `log_seq` ascending
- rollback restores pre-batch cursor and trace tracker state
- batch size affects transaction boundaries, not output semantics
