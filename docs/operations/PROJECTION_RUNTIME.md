# Projection Runtime Operations

## Purpose

This document explains how to inspect and recover the Phase 4 projector runtime without querying tables by hand first.

## Primary Operator Surfaces

### Runtime Snapshot

Use:

- `DecisionGraph.Projector.runtime_snapshot/0`

This is the lightweight topology view. It reports:

- active worker count
- active replay job count
- partition count
- projection names

### Projection Health

Use:

- `DecisionGraph.Projector.projection_health/1`

This is the main health surface for one tenant. It reports:

- event-log tail sequence
- per-projection cursor position
- pending event count
- stale versus current state
- per-projection digest values
- open failure counts
- active queued or running replay jobs
- full projection digest

### Worker Status

Use:

- `DecisionGraph.Projector.worker_status/2`

This is the best view of one worker process. It reports:

- current cursor
- last sync time
- retry count
- last error payload
- status such as `:idle`, `:retrying`, or `:failed`
- sync count

### Replay Controls

Use:

- `DecisionGraph.Projector.replay/2`
- `DecisionGraph.Projector.rebuild/2`
- `DecisionGraph.Projector.replay_status/1`
- `DecisionGraph.Projector.cancel_replay/1`

These are internal operator controls. They are not public network APIs.

## Normal States

Healthy steady-state projection behavior looks like:

- worker status is `:idle`
- `pending_events` is `0` or temporarily low
- no open failures exist
- no unexpected queued or long-running replay jobs exist
- digest rows have recent `updated_at` values

## Degraded States

### Stale Projection

Symptoms:

- `pending_events > 0`
- `is_stale == true`

Likely causes:

- worker not started for that scope
- worker retrying after a storage issue
- replay or rebuild paused before reaching tail

First checks:

1. inspect `worker_status/2`
2. inspect `projection_health/1`
3. inspect active replay jobs

### Retrying Worker

Symptoms:

- worker status is `:retrying`
- `retry_count > 0`
- no open terminal failure row yet

Interpretation:

- the runtime considers the error recoverable, usually a datastore-facing failure
- the worker is using exponential backoff rather than losing cursor position

### Failed Worker

Symptoms:

- worker status is `:failed`
- one or more open rows exist in `dg_projection_failures`

Interpretation:

- the runtime hit a non-recoverable error category, or exhausted retries
- projection state is still durable up to the last committed cursor

Common causes:

- schema-violating event payload
- persistent storage error
- replay-time semantic mismatch such as `trace_seq` or payload-hash drift

## Safe Recovery Flow

### When The Failure Is Transient

Examples:

- database unavailable for a short time
- temporary repo startup or connectivity problem

Operator flow:

1. restore datastore availability
2. check that the worker resumes or start an explicit replay
3. verify `pending_events` returns to `0`
4. verify the open failure count resolves

### When The Failure Is Semantic

Examples:

- invalid `PolicyEvaluated` payload
- invalid `ExceptionRequested` payload
- payload hash mismatch
- replay-time `trace_seq` gap

Operator flow:

1. inspect the open failure row and failing `event_id`
2. confirm whether the event log itself is wrong or the projector logic is wrong
3. fix the underlying cause before restarting work
4. rerun `rebuild/2` for the affected projection, or `rebuild(:all, ...)` if broader confidence is needed

## Replay And Rebuild Expectations

Use replay when:

- a worker fell behind but projection tables are still trusted

Use rebuild when:

- the projection tables must be regenerated from origin
- a semantic bug or migration requires clearing derived state

Remember:

- rebuild never mutates the append-only event log
- replay and rebuild status should be inspected through `replay_status/1` and `projection_health/1`

## Tables Worth Checking After The API Surface

Only after using the runtime surfaces above, the next SQL-backed inspection points are:

- `dg_projection_cursors`
- `dg_projection_digests`
- `dg_projection_failures`
- `dg_projection_runs`

Those tables explain most projector incidents directly.

## Config Knobs

The main operational tuning settings are:

- `projection_batch_size`
- `projection_job_batch_size`
- `projection_poll_interval_ms`
- `projection_retry_base_ms`
- `projection_max_retries`
- `projection_partitions`

Phase 4 should prefer clear operator actions over hidden automation. If the runtime is degraded, it should be obvious which projection is behind, which run owns replay, and which event caused the last terminal failure.
