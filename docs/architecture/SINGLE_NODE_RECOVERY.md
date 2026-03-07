# Single-Node Recovery

## Purpose

This document defines the restart and recovery model for the first supported self-hosted DecisionGraph topology:

- one BEAM node
- one Postgres instance
- optional OTEL collector

The goal is to describe what survives restarts, what must be reloaded, and what an operator should expect after interruptions.

## Recovery Principles

- Postgres is authoritative for durable state.
- The append-only event log remains the source of truth.
- Projection and workflow state are durable, but they are recoverable from the event log if necessary.
- In-memory worker state is disposable and must never be the only copy of progress.

## Component Recovery Model

### Store

What survives restart:

- `dg_event_log`
- `log_seq` progression
- idempotency records embedded in the event log
- projection cursor rows
- workflow tables

What reloads on restart:

- Ecto repo processes
- connection pools
- per-request context

Recovery expectation:

- if Postgres is intact, committed writes remain available after the BEAM node restarts
- if a client retries a write after uncertainty, the normal idempotency path should be used instead of manual duplicate cleanup

### API And Web

What survives restart:

- nothing API-specific needs in-memory recovery beyond normal runtime config
- request-scoped data is intentionally ephemeral

Recovery expectation:

- `/api/healthz` should return `200` once the endpoint is listening and the repo can reach Postgres
- persisted traces, workflows, and projection health should be readable again without re-ingesting data

### Projector

What survives restart:

- durable cursor position in `dg_projection_cursors`
- digests in `dg_projection_digests`
- operator-visible run history in `dg_projection_runs`
- failure records in `dg_projection_failures`

What reloads on restart:

- dynamic projection workers
- retry counters
- in-memory replay bookkeeping

Recovery expectation:

- workers restart from the durable cursor rather than replaying from memory assumptions
- stale projections should catch up from the next poll or explicit replay request
- a partially completed replay does not corrupt the event log

Current caveat:

- a run that died mid-process may still appear as `running` in `dg_projection_runs` until an operator inspects it and decides whether to start a fresh replay or rebuild

### Workflow Runtime

What survives restart:

- `dg_workflow_runtime`
- `dg_workflow_items`
- `dg_workflow_actions`
- `dg_workflow_notifications`

What reloads on restart:

- read-triggered workflow refresh execution
- console snapshot assembly

Recovery expectation:

- workflow items remain durable
- the first inbox, detail, export, or console read after restart advances the workflow runtime again if new source events exist

## Interrupted Operation Semantics

### Interrupted Writes

If the event commit reached Postgres before the crash:

- the event remains durable
- the projector may simply need to catch up after restart

If the write did not commit and the caller is unsure:

- retry with the same idempotency key
- do not hand-edit the event log

### Interrupted Replay Or Rebuild

If the node dies during replay:

- progress already written to projection tables and cursors remains durable
- the event log is unchanged
- operator-visible run history stays in `dg_projection_runs`

Recovery action:

1. inspect projection health and replay status
2. if the run is stale or orphaned, start a fresh `catch_up` or `rebuild`
3. verify the projection reaches the event-log tail

### Interrupted Workflow Actions

Workflow actions are backed by durable workflow tables and, where applicable, source events.

Recovery action:

1. reload the workflow detail view
2. confirm whether the action is already present in `dg_workflow_actions`
3. retry only if the intended action was not durably recorded

## Healthy After Restart

The supported topology is considered healthy after restart when all of these are true:

- `/api/healthz` returns `200`
- `DecisionGraph.Store.deployment_snapshot/0` reports `repo_started? == true`
- `GET /api/v1/projections/health` succeeds for the expected tenant
- projections are either current or clearly progressing toward current state
- no unexpected open failure rows are blocking normal operation
- at least one previously persisted trace can still be read
- at least one previously persisted workflow item can still be read when workflows exist

## Tested Evidence

Phase 8 evidence now includes all of these:

- live source-based node restart drill against `phase8-restart-trace`
- `mix test apps/dg_projector/test/decision_graph/projector/integration_test.exs`
- `DG_RUN_SERVICE_E2E=1 mix test apps/dg_web/test/decision_graph_web/controllers/api_service_e2e_test.exs`

Those proofs establish:

- durable trace persistence across BEAM restart
- workflow inbox recovery after restart
- projection worker restart from durable cursor state
- authenticated end-to-end API and workflow behavior on local Postgres
