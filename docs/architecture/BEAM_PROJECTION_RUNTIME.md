# BEAM Projection Runtime

## Purpose

This document describes the Phase 4 projector runtime that lives in `dg_projector`.

The goal is to keep pure projection logic deterministic and testable while making long-lived catch-up, replay, and failure handling explicit under OTP.

## Runtime Principles

- keep event-to-projection logic in plain modules such as `DecisionGraph.Projector.Write`, `DecisionGraph.Projector.Query`, and `DecisionGraph.Projector.Digests`
- keep lifecycle, retries, polling, and replay coordination in supervised processes
- treat durable cursor state as Postgres-owned and restart-safe
- treat in-memory worker state as operational metadata that can be rebuilt after restart

## Supervision Layout

Phase 4 extends the `dg_projector` tree to:

```text
DecisionGraph.Projector.Application
|
|-- DecisionGraph.Projector.Registry
|-- DecisionGraph.Projector.WorkerSupervisor
|   `-- DecisionGraph.Projector.ProjectionWorker (dynamic, one per tenant/projection scope)
|-- DecisionGraph.Projector.ReplaySupervisor
|   `-- replay task processes
`-- DecisionGraph.Projector.ReplayCoordinator
```

## Worker Scope

Each `ProjectionWorker` owns one logical scope:

- one `tenant_id`
- one projection name from `:context_graph`, `:trace_summary`, `:precedent_index`
- one deterministic partition number derived from `:erlang.phash2({tenant_id, projection})`

The worker key is:

- `%{tenant_id: ..., projection: ..., partition: ...}`

The registry name is:

- `"{tenant_id}:{projection}:{partition}"`

## Worker Lifecycle

### Boot

On startup the worker:

- emits `[:projector, :worker, :started]`
- initializes in-memory cursor state conservatively and recovers the durable cursor during catch-up
- initializes in-memory status fields such as `last_sync_at`, `retry_count`, and `last_error`
- schedules an immediate boot sync

### Catch-Up

During a sync cycle the worker:

- calls `DecisionGraph.Projector.Engine.catch_up/2`
- processes event-log batches from the last durable cursor
- updates its in-memory cursor and sync metadata after success
- emits `[:projector, :worker, :sync]`

### Idle Polling

After a successful sync the worker schedules the next poll using:

- `:projection_poll_interval_ms`

This keeps the projector current without pushing projection logic into the store write path.

### Retry

If a sync fails with a recoverable `DecisionGraph.Error` category, the worker:

- increments `retry_count`
- schedules a retry using exponential backoff
- reports status as `:retrying`

Backoff is controlled by:

- `:projection_retry_base_ms`
- `:projection_max_retries`

### Failed

If an error is non-recoverable, or retries are exhausted, the worker:

- records the failure in `dg_projection_failures`
- keeps the worker alive but marks status as `:failed`
- preserves the last durable cursor rather than advancing into partially valid state

### Shutdown And Restart

Worker processes are disposable.

On restart they recover from:

- `dg_projection_cursors` for durable cursor position
- projection tables for materialized state
- `dg_projection_failures` and `dg_projection_runs` for operator history

They do not rely on recovering any prior in-memory state.

## Replay Runtime

Ad hoc replay and rebuild work is owned by `DecisionGraph.Projector.ReplayCoordinator`.

It is responsible for:

- starting replay or rebuild jobs
- ensuring only one job runs per `{tenant_id, projection}` scope at a time
- tracking active jobs in memory
- persisting operator-visible run state in `dg_projection_runs`
- delegating the actual work to plain projector modules running under `DecisionGraph.Projector.ReplaySupervisor`

## Memory Versus Postgres

### In Memory

- worker process status
- retry counters
- last observed error payload
- active replay job bookkeeping

### In Postgres

- projection tables
- durable cursors in `dg_projection_cursors`
- projection digests in `dg_projection_digests`
- open and resolved failures in `dg_projection_failures`
- replay and rebuild job history in `dg_projection_runs`

## Config Surface

Phase 4 projector behavior is shaped by these application settings:

- `:projection_batch_size`
- `:projection_job_batch_size`
- `:projection_max_edges`
- `:projection_max_nodes`
- `:projection_max_retries`
- `:projection_partitions`
- `:projection_poll_interval_ms`
- `:projection_retry_base_ms`

## What This Runtime Deliberately Does Not Do

Phase 4 keeps the runtime intentionally small.

It does not yet introduce:

- cross-node projector ownership
- public network replay APIs
- workflow-specific worker pools
- automatic dead-letter replay
- projection-specific top-level supervisors beyond the current dynamic worker model

Those decisions should wait until Phase 5 and later operator feedback.
