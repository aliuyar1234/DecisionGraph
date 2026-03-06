# Precedent and Graph Query Semantics

This document focuses on the two most BEAM-sensitive query surfaces: graph traversal and precedent lookup.

## Context Graph Semantics

The graph is an event-derived context model, not a general-purpose graph database.

Frozen expectations:

- node and edge IDs are deterministic
- `TraceStarted` and `EntityObserved` create trace/entity structure
- `PolicyEvaluated` creates policy structure
- `ExceptionRequested` creates exception structure
- `ApprovalRecorded` creates approver nodes and exception approval edges only when the subject is an exception
- `PrecedentCited` creates a trace-to-trace citation edge
- `ActionProposed` creates action nodes plus trace and target-entity edges
- `ActionCommitted` creates a trace-to-action commit edge

## Scoped Subgraph Behavior

`get_context_subgraph()` performs breadth-first traversal from the center node.

Frozen behavior:

- traversal is scoped by `max_depth`
- edge rows are visited in deterministic `edge_id` order
- returned nodes are sorted by `node_id`
- returned edges are sorted by `edge_id`
- truncation is explicit when `max_nodes` or `max_edges` limits are hit

## Edge Pagination

`list_node_edges()` is a cursor-based API over graph edges.

Frozen behavior:

- results are sorted by `log_seq ASC, edge_id ASC`
- cursor state is effectively `(log_seq, edge_id, direction)`
- pagination must be stable across repeated calls

## Precedent Search Semantics

`find_precedents()` only returns finished traces.

When `policy_id` is provided:

- the search joins `dg_trace_summary` with `dg_precedent_index`
- rows are deduplicated to at most one result per trace
- exception-derived rows are preferred over policy-only rows within the same trace
- ties within a trace break by `pi.log_seq DESC, pi.source_event_id ASC`

Final result ordering is:

- `last_log_seq DESC`
- `trace_id ASC`

When `policy_id` is not provided:

- the search scans `dg_trace_summary`
- policy-less traces remain discoverable

## Staleness Rule

Both graph and precedent queries are projection-backed reads and must reject stale projections.
