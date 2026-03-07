# Phase 8 Capacity Model

## Purpose

This note records the first local-first capacity guidance for the supported self-hosted DecisionGraph topology.

It is based on the current Phase 8 benchmark captures, not on hypothetical cloud scaling.

## Supported Benchmark Profiles

Future releases should keep tracking at least these profiles:

- projector rebuild and catch-up throughput via `mix dg.projector.bench`
- authenticated HTTP latency via `mix dg.api.bench`
- controlled restart drill with persisted trace and workflow reads afterward

## Captured Environment

- capture date: `2026-03-07`
- commit SHA: `e642ccee946d2280d4b3953f00b38d2e57fcf2d8`
- host OS: `win32/nt`
- CPU: `AMD Ryzen 9 9950X 16-Core Processor`
- logical processors: `32`
- RAM: `61.65 GiB`
- Postgres: `PostgreSQL 16.11 (Debian 16.11-1.pgdg13+1)` via local Docker
- supported topology: one BEAM node plus one Postgres instance

## Projector Benchmark Capture

Command:

```bash
cd beam
set MIX_ENV=test
mix dg.projector.bench --traces 200 --events-per-trace 6 --batch-size 250 --payload-bytes 512
```

Result:

- traces: `200`
- total source events: `2400`
- replay source events: `1200`
- replay ms: `8460.7`
- replay source events per second: `141.83`
- replay projection events per second: `425.5`
- catch-up source events: `1200`
- catch-up ms: `8857.7`
- catch-up source events per second: `135.48`
- catch-up projection events per second: `406.43`

## API Benchmark Capture

Command:

```bash
cd beam
set MIX_ENV=dev
mix dg.api.bench --seed-traces 60 --seed-events-per-trace 6 --payload-bytes 256 --read-iterations 50 --event-iterations 25 --warmup 5 --port 4104
```

Result:

- seeded traces: `60`
- seeded source events: `360`
- `GET /api/v1/traces/:trace_id` p50: `11.47 ms`, p95: `12.19 ms`
- `GET /api/v1/projections/health` p50: `14.34 ms`, p95: `14.95 ms`
- `POST /api/v1/admin/replays` p50: `15.26 ms`, p95: `16.9 ms`
- `POST /api/v1/events` p50: `23.04 ms`, p95: `24.06 ms`

## Interpretation

- On a strong local workstation, the single-node topology remains comfortably interactive for warm operator traffic and small self-hosted team usage.
- Projector rebuild remains correctness-first and should be treated as background maintenance, not an interactive request path.
- Replay acceptance stays cheap enough to be used as an operator control surface.

## Conservative Self-Hosted Starting Guidance

This guidance is an inference from the measured local results, not a guarantee:

- local evaluation or demo: `4` vCPU, `8 GiB` RAM, SSD-backed Postgres
- small team pilot or home-server install: `8` vCPU, `16 GiB` RAM, SSD-backed Postgres
- if workflow volume or replay frequency grows materially, prioritize faster storage before chasing more application-node complexity

## Main Resource Drivers

The biggest self-hosted cost drivers are:

- Postgres disk and IOPS
- projection rebuild duration on larger event logs
- replay or rebuild frequency
- workflow volume and retention horizon
- API burstiness that creates projector lag

## What Future Releases Must Watch

- API p95 latency regressions against the same benchmark profile
- projector rebuild throughput regressions
- projection lag growth after restart
- backup and restore times as the event log grows
