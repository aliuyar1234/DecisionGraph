# Restart And Recovery Checklist

## Purpose

This checklist defines the minimum verified steps for deciding that a single-node self-hosted DecisionGraph deployment is healthy again after restart or recovery.

## Checklist

- the BEAM runtime starts without manual code changes
- `/api/healthz` returns `200`
- `DecisionGraph.Store.deployment_snapshot/0` or the health response shows `repo_started? == true`
- `GET /api/v1/projections/health` succeeds for the tenant you care about
- projection `pending_events` is `0`, or the node is visibly catching up without new failures
- no unexpected open rows exist in `dg_projection_failures`
- no unexpected replay runs remain stuck in `queued` or `running`
- one known trace can be read successfully
- one known workflow item can be read successfully when workflows exist
- the operator console loads and reflects the same tenant state
- recent logs show request IDs and no uncontrolled retry storm

## Tested Phase 8 Drill

The current Phase 8 restart drill validated all of the following on the supported topology:

- a trace written before restart remained readable after restart
- the related workflow item remained readable after restart
- projection health returned with `pending_events = 0`
- the event-log tail remained unchanged across the controlled restart

Reference evidence:

- `docs/benchmarks/PHASE_8_RESILIENCE_BASELINE.md`
