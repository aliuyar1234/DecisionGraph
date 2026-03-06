# Phase 3 Store Baseline

## Purpose

This note captures the first local benchmark baseline for the Phase 3 BEAM event store.

These numbers are not promises or production targets. They are a reproducible starting point for future comparisons.

## Command

Run from the repo root:

```bash
cd beam
set MIX_ENV=test
mix dg.store.bench --traces 100 --events-per-trace 8 --batch-size 250 --payload-bytes 512
```

Equivalent workload:

- 100 traces
- 8 events per trace
- 800 total events
- 512 bytes of synthetic payload padding
- batch reads of 250 events

## Environment

- host: local Windows development machine
- database: Docker-hosted PostgreSQL using the repo `docker-compose.yml`
- Mix environment: `test`
- repo state: Phase 3 event-store implementation with Postgres trigger-based sequence enforcement and advisory locks

## Result

Measured output:

- `append_ms`: `6421.2`
- `append_events_per_second`: `124.59`
- `batch_read_ms`: `17.0`
- `batch_read_events_per_second`: `47064.36`

## Interpretation

- Append throughput is currently correctness-first rather than optimized. Each write acquires a trace lock, validates parity rules, and commits its own transaction.
- Batch-read throughput is already strong enough for the first projector catch-up and replay workflows planned in Phase 4.
- Future benchmark comparisons should focus on whether we improve append throughput without weakening semantic guarantees.

## Follow-Up Questions

- Should Phase 4 move more validation into fewer round trips while preserving the same error categories?
- Should Phase 4 or Phase 5 introduce write batching for producers that can preserve per-trace ordering?
- When we introduce projector workers, what event-volume target should become the first operator-facing SLO?
