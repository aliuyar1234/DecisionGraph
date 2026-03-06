# V1.0 Scope and Contracts

This page defines the `1.x` compatibility boundary for DecisionGraph.

## Scope-Locked V1

DecisionGraph v1 is intentionally **library-first** and limited to:

- Append-only decision event log
- Deterministic projections
- Query APIs for traces, context graph, and precedents
- Local backends (SQLite and PostgreSQL)
- Read-only CLI inspection commands

Out of scope for v1:

- Workflow orchestration engine
- Policy evaluation engine
- Hosted/SaaS control plane
- Real-time streaming platform

## SemVer Policy

DecisionGraph follows semantic versioning for `decisiongraph` and CLI contracts:

- `MAJOR`: breaking changes to public Python imports, method signatures, event envelope contract, projection schema contract, or CLI command/flag surface.
- `MINOR`: additive, backward-compatible features.
- `PATCH`: backward-compatible bug fixes and docs/test/tooling updates.

## Public Python API Contract

Stable top-level imports for v1:

- `DecisionGraph`
- `DecisionGraphError`
- `ALL_EVENT_TYPES`
- `EVENT_TYPE_TRACE_STARTED`
- `EVENT_TYPE_INPUT_OBSERVED`
- `EVENT_TYPE_ENTITY_OBSERVED`
- `EVENT_TYPE_POLICY_EVALUATED`
- `EVENT_TYPE_EXCEPTION_REQUESTED`
- `EVENT_TYPE_APPROVAL_RECORDED`
- `EVENT_TYPE_PRECEDENT_CITED`
- `EVENT_TYPE_ACTION_PROPOSED`
- `EVENT_TYPE_ACTION_COMMITTED`
- `EVENT_TYPE_TRACE_FINISHED`

Stable public `DecisionGraph` methods for v1:

- `from_postgres(conninfo)`
- `close()`
- `append_event(...)`
- `observe_input(...)`
- `observe_entity(...)`
- `evaluate_policy(...)`
- `request_exception(...)`
- `record_approval(...)`
- `cite_precedent(...)`
- `propose_action(...)`
- `commit_action(...)`
- `start_trace(...)`
- `finish_trace(...)`
- `get_trace_events(trace_id)`
- `get_context_subgraph(node_type, node_id, max_depth=1)`
- `get_projection_health(include_digests=False)`
- `find_precedents(...)`
- `is_trace_finished(trace_id)`
- `sync_projections(batch_size=None)`
- `replay_projections(batch_size=None)`

## CLI Contract

Stable commands and flags for v1:

- `python -m decisiongraph replay <db>`
- `python -m decisiongraph projection-status <db>`
- `python -m decisiongraph projection-status <db> --include-digests`
- `python -m decisiongraph dump-trace <db> <trace_id>`
- `python -m decisiongraph dump-trace <db> <trace_id> --include-payload`

`replay` is a read-only inspection command: it computes digests from isolated replay state and does not mutate the source database.

Removing or renaming commands/flags is a breaking change.

## Event Envelope Contract

`EventEnvelope` required fields are v1-stable:

- `event_id`
- `trace_id`
- `trace_seq`
- `event_type`
- `occurred_at`
- `source`
- `actor`
- `idempotency_key`
- `payload`
- `schema_version`

Optional envelope fields:

- `correlation_id`
- `causation_event_id`
- `tags`

Compatibility rules:

- Additive payload keys are allowed.
- Removing/renaming required fields is breaking.
- Changing semantics of existing required fields is breaking.
- Increasing validation strictness that rejects previously valid payloads is breaking unless introduced via major version.

## Projection Schema Contract

Stable projection/event storage tables for v1:

- `dg_event_log`
- `dg_trace_summary`
- `dg_cg_nodes`
- `dg_cg_edges`
- `dg_precedent_index`
- `dg_policy_eval_index`
- `dg_projection_meta`

Compatibility rules:

- Adding nullable columns/tables/indexes is additive.
- Renaming/removing columns or tables is breaking.
- Altering existing meaning of projection fields is breaking.

## Enforcement

Contract stability is validated by compatibility tests in `tests/unit/test_public_api_contract.py`.
