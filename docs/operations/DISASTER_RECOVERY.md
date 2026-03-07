# Disaster Recovery

## Purpose

This runbook covers the practical recovery flow for the supported self-hosted DecisionGraph deployment.

It is intentionally single-node and Postgres-first.

## Recovery Priorities

In order:

1. protect the append-only event log
2. restore service reachability
3. restore projection readability
4. restore workflow and operator-console usability
5. record what happened and what manual actions were required

## Scenario 1: App Node Restart Or Host Reboot

Symptoms:

- Phoenix is down
- `/api/healthz` is unreachable
- Postgres is still healthy

Operator flow:

1. restart the BEAM runtime
2. wait for `/api/healthz` to return `200`
3. check `GET /api/v1/projections/health`
4. read one known trace
5. read workflow inbox if workflows are in use

Expected outcome:

- persisted traces remain available
- workflow items remain available
- projections are current or catching up from durable cursors

## Scenario 2: Postgres Temporarily Unavailable

Symptoms:

- health degrades or read/write surfaces fail
- logs show repo or query failures

Operator flow:

1. restore Postgres availability first
2. restart the app node if the runtime does not reconnect cleanly
3. check `/api/healthz`
4. check projection health for lag or open failures
5. run an explicit replay only if projections remain stale after recovery

## Scenario 3: Projection Corruption Or Stale Reads

Symptoms:

- `GET /api/v1/projections/health` shows stale projections or open failures
- trace reads return `409` or look incomplete
- operator console shows replay or digest concerns

Operator flow:

1. inspect projection health and open failure rows
2. decide whether `catch_up` is sufficient or `rebuild` is safer
3. run the replay or rebuild with an explicit reason
4. verify projections return to `pending_events = 0`
5. re-read the affected trace or graph surface

## Scenario 4: Suspected Event-Log Damage

Symptoms:

- invalid payload-hash drift
- impossible trace ordering
- restore drill or parity behavior suggests source-of-truth damage

Operator flow:

1. stop writes
2. preserve the broken database for investigation
3. restore the latest known-good Postgres backup
4. restart DecisionGraph
5. verify health and trace readability
6. rebuild projections if needed

Never try to repair the event log manually in place unless you are doing deliberate low-level forensics outside the supported operator flow.

## Scenario 5: Failed Upgrade

Symptoms:

- the new release boots but smoke checks fail
- migrations succeed but core reads or projection health regress

Operator flow:

1. stop the upgraded runtime
2. restore the pre-upgrade backup
3. return to the previous known-good source release or git SHA
4. restart the runtime
5. re-run smoke tests

This is the official rollback model.

## Manual Actions That Are Still Required

Phase 8 is honest about what is still operator-driven:

- deciding whether a replay run left behind after a crash should be ignored, retried, or replaced with rebuild
- deciding whether a projection problem is semantic or transient
- restoring the correct backup artifact after failed upgrades
- maintaining and testing service-account configuration for non-dev installs

## Recovery Checklist

Use the detailed checklist in:

- `docs/operations/RESTART_AND_RECOVERY_CHECKLIST.md`

That checklist is the operational gate for declaring the node healthy again.
