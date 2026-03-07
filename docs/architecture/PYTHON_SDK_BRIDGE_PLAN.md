# Python SDK Bridge Plan

## Purpose

This document defines how Python consumers should relate to the BEAM platform if DecisionGraph ever moves semantic authority from Python to Elixir.

It answers a narrower question than the full authority decision:

- if Elixir becomes authoritative, what happens to Python users
- which Python surfaces stay local
- which platform surfaces become service-only
- how do we avoid surprise breakage for GitHub-download and self-hosted users

## Final Phase 9 Rule

After Phase 9, the Python package remains the semantic reference for the frozen Phase 1 scope.

The existing Python entrypoints remain local and embedded:

- `DecisionGraph(...)` means local SQLite-backed execution
- `DecisionGraph.from_postgres(...)` means local embedded Postgres-backed execution
- the Python CLI remains a local/reference tool

These entrypoints must not silently start talking to a BEAM HTTP service.

## Chosen Bridge Model

If Elixir becomes authoritative, the bridge model should be explicit dual-surface support rather than silent substitution.

The plan is:

- keep `decisiongraph` as the Python package name
- keep `DecisionGraph` as the explicit local embedded/reference surface
- introduce a separate explicit Python service client surface for BEAM-backed operation
- keep parity/reference assets in Python even if authority later moves to Elixir

Recommended future service-client shape:

- `decisiongraph.service.DecisionGraphServiceClient`

Optional convenience factory if it is later implemented:

- `DecisionGraph.from_service(base_url=..., token=..., tenant_id=...)`

The important rule is that remote mode must always be opt-in and visually obvious in code.

## Bridge Options Considered

### Option A: Silent auto-routing from Python to BEAM

Rejected.

Why:

- it would make local and remote behavior ambiguous
- it would create hidden auth and network dependencies
- it would be dangerous for self-hosted users who expect a local library
- it would make rollback harder because the same API call would change execution mode invisibly

### Option B: Replace `DecisionGraph` with a remote client

Rejected.

Why:

- it would break the embedded local use case too abruptly
- it would erase the current reference/testing surface
- it would punish offline and single-process workflows that still have value

### Option C: Explicit dual-surface model

Chosen.

Why:

- it preserves local/reference use cases
- it gives Python users a clear path to the BEAM service
- it makes versioning and rollback more predictable
- it fits the project's local-first and self-hosted direction

## Surface Ownership

### Python-local and embedded-friendly surfaces

These should remain Python-friendly even if Elixir later becomes authoritative:

- local fixture loading and parity/reference tooling
- canonical JSON and payload-shape reference helpers where they are still useful for tests
- local CLI/reference commands
- explicit local embedded store modes used for offline tests, fixtures, and reference comparisons

These may remain supported in one of two forms:

- long-term compatibility mode
- maintenance-mode reference tooling

That final choice belongs to the authority decision itself, not just the bridge plan.

### Service-first surfaces

These should be treated as BEAM service capabilities rather than Python embedded-library promises:

- authenticated multi-user event ingestion
- projection health and replay administration
- workflow inboxes, review actions, and escalation
- operator console behavior
- shared self-hosted runtime orchestration

Python can still consume these features, but it should do so through an explicit service client, not by embedding the runtime.

## Python Method Mapping

If a Python service client is added, the mapping should follow the current BEAM HTTP service surface.

Suggested mapping:

| Python SDK surface | Mode | BEAM route |
| --- | --- | --- |
| `append_event()` and typed write helpers | remote | `POST /api/v1/events` |
| `get_trace(trace_id)` | remote | `GET /api/v1/traces/:trace_id` |
| `get_context_subgraph(...)` | remote | `GET /api/v1/graph/context` |
| `list_node_edges(...)` | remote | `GET /api/v1/graph/edges` |
| `find_precedents(...)` | remote | `GET /api/v1/precedents` |
| `get_projection_health()` | remote | `GET /api/v1/projections/health` |
| `replay_projections()` or admin replay helpers | remote/admin | `POST /api/v1/admin/replays` plus polling routes |

Some local Python methods do not have a 1:1 remote equivalent today.
For example, the local Python API has direct embedded projection control, while the service path exposes replay and health through explicit admin endpoints and polling.

That difference is acceptable as long as semantic outcomes remain aligned and the client makes the asynchronous behavior explicit.

## Error and Semantics Mapping

The Python service client should preserve semantic categories, not raw transport shapes.

Rules:

- HTTP errors should map to the same semantic categories already used by the Python library
- `projection_out_of_date` must remain an explicit retry or polling signal
- idempotency, trace-sequence, and conflict failures must remain distinguishable
- human-readable message text may differ, but semantic category must not silently change

## Auth and Tenant Model

The future Python service client should make BEAM auth explicit:

- `base_url`
- bearer token
- tenant identifier
- optional request ID

These inputs should be constructor-level configuration, not hidden global environment requirements.

## Versioning and Release Policy

The bridge model requires conservative release rules.

Additive changes allowed in a minor release:

- adding a new explicit Python service client
- adding helper factories for explicit remote mode
- adding new documentation and migration aids

Changes that require a major release:

- changing semantic authority
- changing any default execution mode
- deprecating or removing Python local constructors
- changing Python APIs from local-only to remote-only by default

No patch or minor release may silently change `DecisionGraph(...)` from local embedded behavior into remote network behavior.

## Dual-Language Transition Rules

During any authority-handoff candidate period:

- Python local reference tests must still pass
- BEAM parity suites must stay green
- the fixture bundle remains a shared release gate
- any Python service client must be tested against a real BEAM service instance
- migration guidance must be published before any default changes are considered

## Migration Stages

Recommended rollout order:

1. Current state: Python authoritative, no Python service client required
2. Bridge introduction: add explicit Python service client without changing existing local Python behavior
3. Dual-support period: local Python remains available while BEAM-backed Python client is documented and tested
4. Authority decision: decide whether Python stays authoritative or Elixir becomes authoritative
5. Post-decision cleanup: deprecate only what is explicitly chosen, never by implication

## Standing Recommendation

For the current repo state:

- keep the existing Python package local and explicit
- do not add silent transport magic
- if a Python service client is built, make it a separate explicit surface
- preserve local or reference Python tooling as part of the long-term product split
