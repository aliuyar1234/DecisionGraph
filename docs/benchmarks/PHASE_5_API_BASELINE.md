# Phase 5 API Baseline

## Purpose

This note records the first repeatable HTTP baseline for the Phase 5 service surface.

Phase 5 now ships a dedicated benchmark runner in `beam/apps/dg_web/lib/mix/tasks/dg.api.bench.ex`, exposed as:

```bash
cd beam
set MIX_ENV=dev
mix dg.api.bench --seed-traces 40 --seed-events-per-trace 6 --payload-bytes 256 --read-iterations 40 --event-iterations 20 --warmup 5 --port 4103
```

The runner:

- boots the real Phoenix/Bandit endpoint on a local port
- seeds deterministic trace data into Postgres
- warms projections before read/admin captures
- drives authenticated HTTP requests through the actual network path
- records p50, p95, mean latency, and request throughput for the main Phase 5 flows

Implementation note:

- the runner uses local `curl` subprocesses for the request transport so the benchmark exercises real JSON HTTP calls consistently across environments
- replay jobs are allowed to complete between iterations, but the timing only measures the `POST /api/v1/admin/replays` acceptance path

## Captured Environment

- capture date: `2026-03-07`
- commit SHA: `b73557b9e2971f60681473030e982f91d25ef8fd`
- mix environment: `dev`
- host: local Windows development machine (`win32/nt`)
- endpoint: `http://127.0.0.1:4103`
- Elixir: `1.19.5`
- OTP: `28`
- Phoenix: `1.8.5`
- Bandit: `1.10.3`
- Postgres: `PostgreSQL 16.11 (Debian 16.11-1.pgdg13+1)` via local Docker
- connection settings: `localhost:5432`, database `decisiongraph_beam_dev`, pool size `10`
- tenant count: `1`
- warm/cold posture: `warm`

## Dataset

- seeded traces: `40`
- seeded events per trace: `6`
- seeded source events: `240`
- write iterations during capture: `20`
- payload bytes per synthetic event: `256`
- benchmark tenant: `bench-http`

## Captured Result

| Flow | Dataset | Warm/Cold | Mean | p50 | p95 | Throughput | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `POST /api/v1/events` | `240 seeded events + 20 writes` | `warm` | `8.29 ms` | `9.22 ms` | `10.34 ms` | `120.57 req/s` | append-only write with projector sync trigger |
| `GET /api/v1/traces/:trace_id` | `40 traces / 240 events` | `warm` | `6.09 ms` | `6.04 ms` | `6.86 ms` | `164.14 req/s` | projection-backed trace read |
| `GET /api/v1/projections/health` | `40 traces / 240 events` | `warm` | `10.01 ms` | `9.83 ms` | `10.85 ms` | `99.93 req/s` | health snapshot with per-projection state |
| `POST /api/v1/admin/replays` | `40 traces / 240 events` | `warm` | `4.68 ms` | `4.50 ms` | `5.22 ms` | `213.71 req/s` | measures replay request acceptance only; completion is awaited outside timing |

## Interpretation

- Trace reads are the fastest measured path in this first capture, which is what we want from projection-backed operator investigation.
- Projection health is slightly slower because it assembles multi-projection status, lag, and queue state in one response.
- Replay request acceptance is cheap when projections are already warm and current; future replay baselines should compare this control-plane cost separately from rebuild duration.
- Event writes remain comfortably sub-11 ms at this scale even with authenticated delivery and projector sync triggering.

## Regression Intent

The goal of this baseline is not one perfect number. The goal is to create a stable comparison point so later Phase 5 and Phase 6 work can detect API regressions instead of debating them from memory.
