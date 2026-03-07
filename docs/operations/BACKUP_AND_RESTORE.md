# Backup And Restore

## Purpose

This runbook defines the minimum supported backup and restore process for self-hosted DecisionGraph installs.

The primary backup target is PostgreSQL.

## What Must Be Protected

At minimum, back up the database that contains:

- `dg_event_log`
- workflow runtime and action tables
- projection state tables

If you keep exported audit artifacts outside Postgres, store those alongside the database backup set, but do not treat them as a substitute for the database.

## Baseline Backup Policy

The supported baseline is:

- one logical PostgreSQL backup at least daily
- one backup immediately before every upgrade
- one periodic restore drill against a non-primary environment

This is the floor, not the ceiling.

## Logical Backup

If PostgreSQL tooling is installed on the host:

```bash
pg_dump \
  --format=custom \
  --dbname="$DATABASE_URL" \
  --file "backups/decisiongraph-$(date +%Y%m%d-%H%M%S).dump"
```

If you are using the repo `docker-compose.yml` Postgres service:

```bash
docker compose exec -T postgres sh -lc \
  "pg_dump -U decisiongraph -d decisiongraph_beam_dev --format=custom -f /tmp/decisiongraph_beam_dev.dump"
docker compose cp postgres:/tmp/decisiongraph_beam_dev.dump backups/decisiongraph_beam_dev.dump
```

For a self-hosted non-dev database, replace `decisiongraph_beam_dev` with your actual runtime database name.

This container-side file workflow is the safest default on Windows.
PowerShell redirection can corrupt `pg_dump --format=custom` archives if you stream them directly to a host file.

## Recommended Backup Metadata

Record these values with every backup:

- timestamp
- git SHA or release tag
- database name
- deployment environment
- whether the backup was scheduled, manual, or pre-upgrade

That metadata makes restore and rollback decisions much safer.

## Restore Procedure

1. stop the DecisionGraph application or block writes
2. confirm the target database name and the backup artifact you intend to restore
3. restore the dump into the target PostgreSQL database
4. restart DecisionGraph
5. run health and projection checks
6. rebuild projections only if the restored state is missing or untrusted

Example restore with host tooling:

```bash
pg_restore \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  --dbname="$DATABASE_URL" \
  backups/decisiongraph_beam_dev.dump
```

## Post-Restore Verification

After restore, verify:

- `GET /api/healthz` returns `200`
- `GET /api/v1/projections/health` succeeds for the expected tenant
- the operator console loads
- recent traces and workflow items look plausible for the restored point in time

## When To Rebuild Projections

Restore should normally keep projection tables.
Rebuild is appropriate when:

- the backup intentionally excluded derived projection tables
- projection tables restored, but their correctness is in doubt
- a known projection bug requires recomputation

Rebuild is not a substitute for restoring the event log.

## Workflow And Audit Exports

Exports are useful for evidence handling and external review, but they are not sufficient disaster-recovery artifacts.

Treat exports as:

- useful companions to the backup set
- not replacements for PostgreSQL dumps

## Restore Drill Expectations

At least periodically, practice this on a non-primary environment:

1. restore the latest backup
2. start the runtime
3. run the smoke tests from `docs/operations/SELF_HOSTED_INSTALL.md`
4. confirm projection health is current or successfully rebuildable
5. record any manual steps that were unexpectedly required

If a restore needs tribal knowledge, the runbook is not good enough yet.
