# BEAM Projection Process Model

## Purpose

This document defines who owns projection work in Phase 4 and how concurrent writers avoid corrupting projection state.

The main question is:

What prevents two projector runtimes from racing the same projection scope?

## Ownership Model

Phase 4 splits responsibility into two layers.

### Layer 1: OTP Ownership

`DecisionGraph.Projector.Runtime` gives every worker a deterministic scope:

- `tenant_id`
- `projection`
- `partition`

`DecisionGraph.Projector.Registry` and `DecisionGraph.Projector.WorkerSupervisor` then ensure that a given scope resolves to at most one local worker process.

### Layer 2: Datastore Ownership

`DecisionGraph.Projector.Write` acquires a Postgres advisory transaction lock for:

- `"{tenant_id}:{projection_name}"`

This means even if two processes try to project the same scope, the projection transaction remains serialized at the database boundary.

## Worker Identities

The worker identity is a map:

- `%{tenant_id: String.t(), projection: atom(), partition: non_neg_integer()}`

The partition value is deterministic:

- `partition = phash2({tenant_id, projection}, partition_count)`

This partition number is currently used as stable identity metadata and future sharding context. It does not mean multiple workers share one tenant/projection scope at the same time.

## Who Owns What

### `ProjectionWorker`

Owns:

- continuous incremental catch-up for one tenant/projection scope
- retry and backoff timing
- in-memory status used by `worker_status/2`

Does not own:

- replay job history
- durable cursor storage
- query semantics
- projection table schemas

### `ReplayCoordinator`

Owns:

- ad hoc replay and rebuild job admission
- one-running-job-per-scope protection
- job cancellation and status inspection
- persistent run records in `dg_projection_runs`

Does not own:

- steady-state polling
- projection row mutation logic
- projection query logic

### `Write`

Owns:

- applying events to projection tables
- cursor advancement
- digest refresh
- failure resolution and failure recording
- rebuild table clearing rules

This module is intentionally not a process.

### `Admin`

Owns:

- projection health snapshots
- replay run listing and point lookups
- failure listing

It is a datastore-backed read surface, not a runtime owner.

## Collision Rules

### Live Worker Versus Live Worker

The intended steady-state path is one worker per scope through the registry and dynamic supervisor.

If duplicate startup is attempted:

- the unique registry name prevents duplicate local registration
- `ensure_worker_started/2` treats `{:already_started, pid}` as success

### Live Worker Versus Replay Job

Both routes ultimately call into the same projection writer and therefore the same advisory-lock key.

That gives Phase 4 two protection layers:

- local scope admission at the coordinator and worker registry
- transaction-time serialization in Postgres

### Replay Job Versus Replay Job

`ReplayCoordinator` refuses to start a second job for the same:

- `{tenant_id, projection}`

This rule also applies to `"all"` jobs once normalized.

## Durable Recovery Model

Process crashes are expected.

Recovery depends on:

- `dg_projection_cursors` for the last committed projection position
- projection tables for already materialized rows
- `dg_projection_runs` for replay status
- `dg_projection_failures` for operator-visible failure state

This keeps worker memory small and disposable.

## Why The Runtime Uses Both Registry Names And SQL Locks

The registry solves:

- local process identity
- idempotent worker startup
- routing calls such as `sync/3` and `worker_status/2`

The SQL advisory lock solves:

- transaction-time mutual exclusion
- safety across worker crashes and overlapping admin jobs
- correctness at the point where projection rows are actually mutated

Either mechanism alone would be incomplete for Phase 4.

## Boundary Rule For Future Work

If a new feature needs:

- retries
- timers
- cancellation
- concurrency admission

it belongs in a process under `dg_projector`.

If it only transforms events into deterministic rows or reads already-materialized state, it should stay in a plain module.
