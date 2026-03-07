# BEAM Projection Replay Behavior

## Purpose

This document freezes the operator-facing replay and rebuild behavior implemented by the BEAM projector runtime in Phase 4.

It complements the semantic reference documents by describing how the OTP runtime drives those same projection rules.

## Replay Modes

Phase 4 exposes two job modes through `DecisionGraph.Projector.ReplayCoordinator`.

### Catch-Up

Catch-up means:

- start from the last durable cursor for the target projection
- read forward in event-log `log_seq` order
- apply the same projection semantics used by live workers
- stop at the current tail, or an optional `until_log_seq`

This is the mode used by steady-state workers and ad hoc replay jobs.

### Rebuild

Rebuild means:

- clear the target projection tables for the tenant
- reset the target durable cursor to `0`
- clear open failure rows for that projection
- replay from event-log origin using the normal catch-up path

For `:all`, rebuild runs projections in this order:

1. `:context_graph`
2. `:trace_summary`
3. `:precedent_index`

## Run States

Replay and rebuild jobs persist status in `dg_projection_runs`.

Current states are:

- `queued`
- `running`
- `completed`
- `failed`
- `cancelled`

Each run also persists:

- `since_log_seq`
- `until_log_seq`
- `processed_events`
- `last_log_seq`
- `error_code`
- `error_message`

## Admission Rules

Only one replay job may run for the same:

- `{tenant_id, projection}`

at a time.

The coordinator enforces this before the task starts.

## Concurrency Guardrails

Even after admission, projection writes still acquire a Postgres advisory transaction lock for:

- `"{tenant_id}:{projection_name}"`

That means:

- two local workers cannot commit the same projection batch concurrently
- a replay job and a steady-state worker cannot corrupt the same projection scope
- replay safety does not depend only on in-memory coordination

## Batch And Checkpoint Rules

During catch-up and replay:

- events are streamed in ascending `log_seq`
- per-trace `trace_seq` is revalidated
- payload hashes are revalidated
- a batch commits only if every event in that batch succeeds

At the end of a successful batch the runtime:

1. updates `dg_projection_cursors`
2. resolves open failures at or below the committed `last_log_seq`
3. refreshes `dg_projection_digests`

If a batch fails, the transaction rolls back and the durable cursor remains unchanged.

## Failure Behavior

Replay failures are reported in two layers.

### Run-Level Failure

The replay job itself is marked `failed` in `dg_projection_runs`, including:

- `processed_events`
- `last_log_seq`
- `error_code`
- `error_message`

### Projection Failure Row

When a live worker reaches a terminal failure, it records an open row in:

- `dg_projection_failures`

That row includes the failed event identity, retry count, recoverability flag, and operator metadata.

## Cancellation

`cancel_replay/1` stops the running replay task and marks the run:

- `cancelled`

Cancellation does not roll back already committed batches.

The next catch-up or replay resumes from the last durable cursor already stored in Postgres.

## Digest Behavior

Digest rows are refreshed during projection processing, not only after full rebuilds.

This means operators can compare:

- per-projection digest value
- per-projection `last_log_seq`
- full projection digest

while the system is catching up.

## Expected Equivalence

For the same tenant event log, these paths are expected to converge on identical projection state:

- continuous worker catch-up
- ad hoc catch-up replay
- rebuild from origin

If they do not converge, that is a correctness bug, not an acceptable runtime variation.
