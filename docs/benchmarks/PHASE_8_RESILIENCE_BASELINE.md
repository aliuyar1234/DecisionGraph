# Phase 8 Resilience Baseline

## Purpose

This note records the first evidence-backed resilience drill set for the supported self-hosted topology.

It is meant to answer one question:

- can a GitHub-downloaded, single-node DecisionGraph install be started, backed up, restored, restarted, and trusted again without hidden steps

## Captured Environment

- capture date: `2026-03-07`
- commit SHA: `e642ccee946d2280d4b3953f00b38d2e57fcf2d8`
- host OS: `win32/nt`
- topology: one BEAM node plus one Docker-hosted Postgres 16.11 instance

## Install Validation

Command path:

```bash
docker compose up postgres otel-collector -d
cd beam
mix setup
```

Result:

- local dependencies started successfully
- `mix setup` completed successfully on the supported source path
- the current umbrella alias no longer emits deprecated `mix cmd --app` warnings
- this validated the current bootstrap path documented in `docs/operations/SELF_HOSTED_INSTALL.md`

## Backup Artifact Drill

Safe container-side backup flow used for the drill:

```bash
docker compose exec -T postgres sh -lc "pg_dump -U decisiongraph -d decisiongraph_beam_dev --format=custom -f /tmp/phase8_valid.dump"
docker compose cp postgres:/tmp/phase8_valid.dump .tmp/phase8/phase8_valid.dump
```

Observed backup artifact:

- path: `.tmp/phase8/phase8_valid.dump`
- size: `144057` bytes

Important finding:

- Windows PowerShell host-side redirection is not a safe default for `pg_dump --format=custom`
- the release runbook now recommends container-side dump creation plus `docker cp`

## Restore Drill

Restore path:

```bash
docker compose exec -T postgres psql -U decisiongraph -d postgres -c "CREATE DATABASE decisiongraph_phase8_restore OWNER decisiongraph"
docker compose exec -T postgres pg_restore -U decisiongraph -d decisiongraph_phase8_restore --clean --if-exists --no-owner --no-privileges /tmp/phase8_valid.dump
```

Verification:

- source `dg_event_log` row count: `1185`
- restored `dg_event_log` row count: `1185`

Result:

- restore succeeded against a throwaway database
- row counts matched for the authoritative event log

## Migration And Upgrade Validation

Current Phase 8 release validation is source-based.
For this release posture, upgrade validation means:

- the source artifact bootstraps cleanly
- migrations run cleanly or no-op cleanly
- rollback remains backup-first rather than in-place down-migration-first

The current install and restore drills validated that posture on the supported topology.

## Controlled Restart Drill

Drill summary:

1. started `mix phx.server`
2. confirmed `/api/healthz` returned `200`
3. wrote trace `phase8-restart-trace` plus an `ExceptionRequested` event through the authenticated HTTP API
4. confirmed trace and projection health were readable
5. stopped the BEAM node
6. started it again
7. confirmed the same trace and its workflow item were still readable

Recovered state after restart:

- recovered trace events: `3`
- recovered workflow id: `phase8-restart-trace:exception:ex-phase8-1`
- recovered workflow status: `requested`
- event log last seq: `2168`
- projection pending events: `0`
- stale projections: `0`

Result:

- persisted trace and workflow data survived the controlled BEAM restart
- the node returned to a healthy projection posture after restart

## Automated Recovery Evidence

Targeted projector recovery suite:

```bash
cd beam
set MIX_ENV=test
mix test apps/dg_projector/test/decision_graph/projector/integration_test.exs
```

Result:

- `5 tests, 0 failures`

This suite covers:

- durable cursor resume
- replay run persistence
- worker restart from durable cursor state
- operator-visible projection failure recording

Authenticated service E2E suite:

```bash
cd beam
set MIX_ENV=test
set DG_RUN_SERVICE_E2E=1
mix test apps/dg_web/test/decision_graph_web/controllers/api_service_e2e_test.exs
```

Result:

- `3 tests, 0 failures`

This suite covers:

- authenticated event writes
- projection-backed trace reads
- workflow inbox and approval flows
- workflow studio review creation

## Benchmark Evidence

Phase 8 local-hosting performance evidence now lives in:

- `docs/benchmarks/PHASE_8_CAPACITY_MODEL.md`

That note captures the current API and projector throughput baselines for the supported single-node topology.
