# Phase 4 Projector Baseline

## Purpose

This note defines the first repeatable baseline for the Phase 4 projector runtime.

Phase 4 now ships a dedicated benchmark task in `mix dg.projector.bench`. This note captures:

- the workload to run
- the metrics to record
- the interpretation rules for future comparisons

## Baseline Workload

The first projector baseline should measure all of the following against the same tenant:

- append the frozen fixture bundle from `tests/golden/reference_fixture_bundle.json`
- run a full `rebuild_all`
- run a no-op catch-up immediately afterward
- capture the resulting projection health snapshot

This gives one correctness-oriented baseline that exercises:

- context graph writes
- trace summary writes
- precedent index rebuilds
- digest refresh
- durable cursor progression

## Suggested Capture Procedure

Run from the repo root:

```bash
cd beam
set MIX_ENV=test
mix dg.projector.bench --traces 100 --events-per-trace 6 --batch-size 250 --payload-bytes 512
```

This command measures:

- full `rebuild_all`
- incremental catch-up after appending a second benchmark workload
- source-event throughput and projection-event throughput

## Metrics To Record

Record at least:

- `fixture_scenarios`
- `fixture_events`
- `rebuild_ms`
- `rebuild_events_per_second`
- `catch_up_ms`
- `catch_up_events_per_second`
- final per-projection cursor values
- final `pending_events`
- final digest values

## First Baseline Status

The first local Postgres-backed capture is now recorded below.

These numbers are not release targets. They are the first reproducible comparison point for later Phase 4 and Phase 5 runtime work.

## Environment Template

- host:
- database:
- Mix environment:
- repo state:

## Result Template

- `rebuild_ms`:
- `rebuild_events_per_second`:
- `catch_up_ms`:
- `catch_up_events_per_second`:
- `full_digest`:

## Captured Environment

- host: local Windows development machine
- database: Docker-hosted PostgreSQL using the repo `docker-compose.yml`
- Mix environment: `test`
- repo state: Phase 4 projector runtime with verified parity suite, replay integration coverage, and benchmark task isolation fixes

## Captured Result

- `rebuild_ms`: `4378.62`
- `rebuild_events_per_second`: `137.03`
- `catch_up_ms`: `4191.23`
- `catch_up_events_per_second`: `143.16`
- `full_digest`: `sha256:69c20bbcf44a30f2018dfcfe8fd68dd6c64acbddeca885ac8bd743cf944e24a9`

## Interpretation

- Rebuild throughput is expected to be correctness-first. It revalidates payload hashes and per-trace sequence monotonicity while refreshing digests and cursor state.
- A no-op catch-up should be dramatically faster than rebuild because it should confirm the tail without rewriting projection rows.
- Future comparisons should focus on reducing replay time without relaxing determinism, stale-read safety, or failure visibility.
