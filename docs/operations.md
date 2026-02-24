# Operations Runbook and Reproducibility

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
2. Run projection rebuild:
   - `python -m decisiongraph replay <db>`
3. Verify all digest outputs are present and stable across repeated runs.

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
