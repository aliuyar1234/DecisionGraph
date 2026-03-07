# Upgrade And Rollback

## Purpose

This guide describes the supported upgrade and rollback path for the current self-hosted DecisionGraph deployment model.

The supported path assumes:

- one application node
- one PostgreSQL database
- source-based deployment from this repository

## Supported Upgrade Model

Today the safest supported upgrade flow is:

1. back up PostgreSQL
2. move the source checkout to the target release or git SHA
3. run migrations
4. start the new runtime
5. run smoke tests before trusting the install

## Pre-Upgrade Checklist

Before upgrading:

- record the current git SHA or tag
- record the database name and `DATABASE_URL`
- take a fresh pre-upgrade backup
- read `docs/release.md` for migration notes
- plan a maintenance window if you cannot tolerate brief write interruption

## Upgrade Procedure

From the repository root:

```bash
git fetch --tags
git checkout <target-tag-or-sha>
cd beam
mix deps.get
mix compile
mix ecto.migrate
mix phx.server
```

For non-dev installs, run with the same production environment used by the current deployment, including:

- `MIX_ENV=prod`
- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `PHX_HOST`
- `PORT`
- `POOL_SIZE`
- `PHX_SERVER=true`

## Post-Upgrade Verification

After the new version starts, verify:

- `GET /api/healthz` returns `200`
- authenticated `GET /api/v1/projections/health` returns `200`
- the operator console loads
- replay admission still works for an admin token
- recent traces and workflows render correctly

If those checks fail, do not continue normal traffic.

## Supported Rollback Model

The supported rollback path is conservative:

1. stop the upgraded runtime
2. restore the pre-upgrade PostgreSQL backup
3. check out the previous known-good release or git SHA
4. restart the old runtime
5. re-run the smoke checks

This is the official rollback story because it does not assume every migration is safely reversible in place.

## Rollback Procedure

From the repository root:

```bash
git checkout <previous-tag-or-sha>
cd beam
mix deps.get
mix compile
mix phx.server
```

Before restarting, restore the matching database backup captured before the upgrade.

## When A Projection Rebuild Is Enough

If the upgrade issue only affects derived projection code and the event log remains trustworthy, a full database restore may not be necessary.

A narrower recovery path can be:

1. revert to the previous code version
2. start the runtime
3. rebuild affected projections
4. verify health and digests

Do not use this shortcut when the database migration itself is suspect.

## Unsupported Rollback Tactics

The current supported self-hosted story does not rely on:

- manual table surgery in production
- undocumented down-migration sequences
- restoring projection tables without understanding event-log consistency

If the failure mode is unclear, prefer the full restore-based rollback.
