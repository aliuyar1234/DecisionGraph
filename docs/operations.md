# Operations Runbook and Reproducibility

## Self-Hosted BEAM Operations

For the current BEAM self-hosted platform shape, start with:

- [Self-Hosted Install](operations/SELF_HOSTED_INSTALL.md)
- [Backup and Restore](operations/BACKUP_AND_RESTORE.md)
- [Upgrade and Rollback](operations/UPGRADE_AND_ROLLBACK.md)
- [Disaster Recovery](operations/DISASTER_RECOVERY.md)
- [Restart and Recovery Checklist](operations/RESTART_AND_RECOVERY_CHECKLIST.md)
- [SLOs and Alerting](operations/SLOS_AND_ALERTING.md)
- [Observability Dashboards](operations/OBSERVABILITY_DASHBOARDS.md)
- [Self-Hosted Release Checklist](operations/SELF_HOSTED_RELEASE_CHECKLIST.md)
- [API Runtime](operations/API_RUNTIME.md)
- [Projection Runtime](operations/PROJECTION_RUNTIME.md)
- [Workflow Runtime](operations/WORKFLOW_RUNTIME.md)

The rest of this page remains the cross-backend recovery and reproducibility summary.

## Backup and Restore

### SQLite

- Backup:
  - Stop writers.
  - Copy database file and associated `-wal`/`-shm` files if WAL is enabled.
- Restore:
  - Replace DB files with backup set.
  - Run `python -m decisiongraph replay <db>` and verify digests.

### PostgreSQL

- Backup:
  - Use `pg_dump` for logical backups or storage snapshots for physical backups.
- Restore:
  - Restore dump/snapshot.
  - Re-run projection replay verification and check digest outputs.

## Migration Rollback Strategy

- Never partially apply migrations outside transaction boundaries.
- If migration verification fails:
  1. Stop writes.
  2. Restore latest known-good backup.
  3. Re-run application with previous release artifact.
  4. Confirm event log and projection digests.

## Corruption Recovery

If projection tables are inconsistent:

1. Keep event log as source of truth.
2. Inspect current lag before taking action:
   - `python -m decisiongraph projection-status <db>`
   - `python -m decisiongraph projection-status <db> --include-digests`
3. Run projection rebuild:
   - `python -m decisiongraph replay <db>`
4. Verify all digest outputs are present and stable across repeated runs.

If event log corruption is detected:

1. Quarantine the affected DB snapshot.
2. Restore from backup.
3. Validate idempotency/traces with integration checks before re-enabling writes.

## Reproducibility Guide

Use deterministic digests to prove replay equivalence:

1. Export or snapshot the event log.
2. Rebuild projections in a clean environment:
   - `python -m decisiongraph replay <db>`
3. Record digest values:
   - `context_graph`
   - `trace_summary`
   - `precedent_index`
   - `full_projection`
4. Repeat replay in another environment and compare digests.
5. Treat digest mismatch as release-blocking until root cause is resolved.

## Multi-Writer Projection Monitoring

When multiple writers may append events outside the current process, use projection health checks to detect lag before projection-backed reads:

1. Inspect current state from the CLI:
   - `python -m decisiongraph projection-status <db>`
2. Or inspect in process:
   - `DecisionGraph.get_projection_health(include_digests=True)`
3. If `is_stale` is `true`, either:
   - call `sync_projections()` to catch up incrementally, or
   - call `replay_projections()` if you suspect projection corruption
4. Treat non-zero `pending_events` as an operational signal that projection-backed queries may be stale until catch-up completes.

## BEAM Phase 3 Local Store Workflow

For the Elixir event-store phase, the local operating loop is:

1. Start Postgres from the repo root:
   - `docker compose up postgres -d`
2. Run Elixir store tests:
   - `cd beam`
   - `mix test apps/dg_store/test`
3. Run the local store benchmark in an isolated test database:
   - `set MIX_ENV=test`
   - `mix dg.store.bench --traces 100 --events-per-trace 8 --batch-size 250 --payload-bytes 512`

Phase 3 operator notes:

- the benchmark command is intended for baseline comparison, not for load-testing claims
- `dg_projection_cursors` exists before BEAM projection runtime work so Phase 4 can inherit a stable cursor table
- projection materialization remains a later phase; Phase 3 health is about store correctness, not projector lag
