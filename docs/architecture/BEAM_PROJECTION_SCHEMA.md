# BEAM Projection Schema

## Purpose

This document describes the durable schema Phase 4 uses for projection state, replay bookkeeping, and operator visibility.

## Migration Location

The Phase 4 projection tables currently migrate through the shared `dg_store` repo rather than a dedicated projector repo.

The active migration is:

- `beam/apps/dg_store/priv/repo/migrations/20260307000300_create_dg_projection_runtime_tables.exs`

This keeps all Postgres-backed state on the same repo and connection pool while the BEAM runtime is still consolidating around one datastore boundary.

## Design Rules

- every projection row is tenant-scoped
- stable reads depend on composite unique indexes rather than hidden global identities
- ordering-sensitive tables carry deterministic keys such as `node_id`, `edge_id`, `trace_id`, or `source_event_id`
- replay metadata is kept separate from materialized projection rows
- rebuilds clear projection state and reset durable cursors instead of mutating event-log history

## Table Set

### `dg_projection_cursors`

Purpose:

- durable last-processed `log_seq` per `{tenant_id, projection_name}`

This table already existed in the store layer and remains the source of truth for catch-up resumption and stale-read checks.

### `dg_cg_nodes`

Purpose:

- durable context-graph nodes

Key columns:

- `tenant_id`
- `node_id`
- `node_type`
- `trace_id`
- `log_seq`
- `created_at`
- `metadata_json`

Important indexes:

- unique `{tenant_id, node_id}`
- lookup by `{tenant_id, trace_id}`
- lookup by `{tenant_id, node_type}`

### `dg_cg_edges`

Purpose:

- durable context-graph edges

Key columns:

- `tenant_id`
- `edge_id`
- `edge_type`
- `from_node_id`
- `to_node_id`
- `trace_id`
- `log_seq`
- `created_at`
- `metadata_json`

Important indexes:

- unique `{tenant_id, edge_id}`
- lookup by `{tenant_id, from_node_id}`
- lookup by `{tenant_id, to_node_id}`
- stable pagination index on `{tenant_id, log_seq, edge_id}`

### `dg_trace_summary`

Purpose:

- one row per finished or in-flight trace with operator and query-facing summary fields

Key columns:

- `tenant_id`
- `trace_id`
- `workflow`
- `title`
- `primary_entity_type`
- `primary_entity_system`
- `primary_entity_id`
- `outcome`
- `started_at`
- `finished_at`
- `event_count`
- `last_log_seq`

Important indexes:

- unique `{tenant_id, trace_id}`
- lookup by `{tenant_id, workflow}`
- lookup by `{tenant_id, outcome}`
- recency ordering on `{tenant_id, last_log_seq}`

### `dg_policy_eval_index`

Purpose:

- append-only policy evaluation rows used while building and rebuilding precedent state

Key columns:

- `tenant_id`
- `index_id`
- `trace_id`
- `policy_id`
- `policy_version`
- `log_seq`
- `created_at`

Important indexes:

- unique `{tenant_id, index_id}`
- lookup by `{tenant_id, trace_id}`
- lookup by `{tenant_id, policy_id, policy_version}`

### `dg_precedent_index`

Purpose:

- finished-trace precedent rows materialized from `PolicyEvaluated` and `ExceptionRequested`

Key columns:

- `tenant_id`
- `source_event_id`
- `log_seq`
- `trace_id`
- `policy_id`
- `policy_version`
- `exception_id`
- `primary_entity_type`
- `primary_entity_system`
- `primary_entity_id`

Important indexes:

- unique `{tenant_id, source_event_id}`
- lookup by `{tenant_id, trace_id}`
- lookup by `{tenant_id, policy_id, policy_version}`
- lookup by `{tenant_id, primary_entity_type, primary_entity_id}`

### `dg_projection_digests`

Purpose:

- durable digest checkpoints per projection plus the synthetic `full_projection` digest

Key columns:

- `tenant_id`
- `projection_name`
- `digest_value`
- `last_log_seq`
- `updated_at`

Important indexes:

- unique `{tenant_id, projection_name}`
- lookup by `{tenant_id, last_log_seq}`

### `dg_projection_failures`

Purpose:

- operator-visible dead-letter style record of projection failures

Key columns:

- `tenant_id`
- `projection_name`
- `log_seq`
- `trace_id`
- `event_id`
- `error_code`
- `error_message`
- `recoverable`
- `retry_count`
- `status`
- `metadata_json`
- `recorded_at`
- `resolved_at`

Important indexes:

- lookup by `{tenant_id, projection_name, status}`
- lookup by `{tenant_id, projection_name, log_seq}`

### `dg_projection_runs`

Purpose:

- replay and rebuild job history

Key columns:

- `job_id`
- `tenant_id`
- `projection_name`
- `mode`
- `status`
- `requested_at`
- `started_at`
- `finished_at`
- `since_log_seq`
- `until_log_seq`
- `processed_events`
- `last_log_seq`
- `error_code`
- `error_message`
- `metadata_json`

Important indexes:

- lookup by `{tenant_id, projection_name}`
- operator queue view by `{status, requested_at}`

## Rebuild Semantics

Projection rebuilds are table-clearing operations scoped by tenant and projection name.

Current behavior:

- `:context_graph` clears `dg_cg_nodes` and `dg_cg_edges`
- `:trace_summary` clears `dg_trace_summary`
- `:precedent_index` clears `dg_precedent_index` and `dg_policy_eval_index`
- the relevant cursor resets to `0`
- open failures for that projection are cleared
- digests are recomputed after reset and again after replay

The event log is never mutated by a projection rebuild.

## Digest Semantics

`dg_projection_digests` stores:

- one row each for `context_graph`, `trace_summary`, and `precedent_index`
- one synthetic row for `full_projection`

The `last_log_seq` on the full digest is the minimum durable cursor across all projections for the tenant. This makes the full digest conservative by design.

## Naming Conventions

Phase 4 uses the `dg_` prefix consistently.

Projection-specific names follow these rules:

- `cg` for context-graph physical tables
- `trace_summary` for one-row-per-trace summary state
- `policy_eval_index` for intermediate policy lookup state
- `precedent_index` for operator and query-facing precedent rows
- `projection_*` for replay, digest, and failure metadata

## Query Safety Notes

The schema is designed to support:

- deterministic `ORDER BY node_id` and `ORDER BY edge_id` reads
- stable graph-edge pagination using `ORDER BY log_seq, edge_id`
- finished-trace precedent ordering using `ORDER BY last_log_seq DESC, trace_id ASC`
- stale-read detection by comparing `dg_projection_cursors` to event-log `MAX(log_seq)`
