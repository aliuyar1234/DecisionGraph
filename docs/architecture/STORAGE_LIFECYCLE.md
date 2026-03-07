# Storage Lifecycle

## Purpose

This document defines how self-hosted operators should think about DecisionGraph data retention, backups, rebuildability, and archival.

The first rule is simple:

- the append-only event log is the source of truth

Everything else is planned around protecting that claim without pretending every table has the same recovery cost.

## Data Classes

### Authoritative Audit History

These records are the hardest to replace and should be retained conservatively:

- `dg_event_log`
- `dg_workflow_actions`

These tables preserve the audit narrative that DecisionGraph exists to protect.

## Durable Operational State

These records are durable and should normally be included in backups even though some of them can be reconstructed:

- `dg_workflow_runtime`
- `dg_workflow_items`
- `dg_workflow_notifications`
- `dg_projection_cursors`
- `dg_projection_runs`
- `dg_projection_failures`

Losing them may not destroy the underlying event history, but it does increase recovery time and can erase operator-facing incident context.

## Rebuildable Derived State

These tables are derived from the event log and can be regenerated:

- `dg_trace_summary`
- `dg_cg_nodes`
- `dg_cg_edges`
- `dg_precedent_index`
- `dg_policy_eval_index`
- `dg_projection_digests`

Operators should still back them up by default because a backup that preserves current projection state is faster to restore than a backup that requires a full rebuild before the system feels usable again.

## Default Retention Policy

The first supported self-hosted policy is conservative:

- do not prune the append-only event log by default
- do not prune workflow audit history by default
- do not rely on ad hoc row deletion while still claiming full replay or audit equivalence

If storage pressure appears, the preferred response is:

1. add storage
2. archive whole backups
3. validate export workflows
4. only design table-level pruning after explicit product work and operator sign-off

## Archival Guidance

The supported archival posture is backup-first, not row-pruning-first.

Recommended artifacts:

- scheduled PostgreSQL logical dumps
- pre-upgrade dumps tied to a tagged application version or git SHA
- exported operator evidence bundles when required by policy or incident workflows

Archived exports are useful supporting artifacts, but they are not a substitute for database backups.

## Backup Cadence Baseline

The minimum reasonable baseline for a self-hosted install is:

- one scheduled logical Postgres backup at least daily
- one additional backup immediately before every upgrade
- at least one periodic restore drill on a non-primary environment

Operators with stricter requirements can layer filesystem snapshots or WAL-based strategies on top, but the minimum supported story is still a repeatable logical dump plus restore drill.

## Rebuild, Retention, And Recovery

Projection rebuild changes recovery posture in an important way:

- loss of projection tables is survivable if the event log is intact
- loss of workflow action history is not treated as acceptable
- restore should prefer keeping both the event log and current projection state when possible

If an operator intentionally restores only the event log:

1. restore the database
2. start the runtime
3. run projection catch-up or rebuild
4. verify projection digests and health before trusting reads

## Audit Exports

Audit exports help with evidence handling, external review, and long-term records, but they do not replace the live datastore.

Specifically:

- exports do not replace `dg_event_log`
- exports do not replace workflow actions or notification history
- exports should be treated as complementary evidence copies

## What We Do Not Support Yet

The current self-hosted posture does not yet define:

- automated hot/cold tier migration
- built-in archival workers
- built-in pruning policies for old traces
- tenant-specific retention windows

Those remain future work and should not be improvised silently in the supported topology.
