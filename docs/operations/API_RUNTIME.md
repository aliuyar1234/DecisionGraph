# API Runtime

## Purpose

This guide describes how to boot, smoke-test, and reason about the Phase 5 BEAM service.

## Prerequisites

You need:

- Elixir and OTP matching the umbrella project
- local Postgres
- the BEAM umbrella dependencies installed

## Startup

From `beam/`:

```bash
mix deps.get
mix ecto.create
mix ecto.migrate
iex -S mix phx.server
```

In development, the Phoenix endpoint listens on:

- `http://localhost:4100`

## Dev Tokens

Development service accounts live in:

- `beam/config/dev.exs`

Current dev tokens:

- `dev-reader-token`
- `dev-writer-token`
- `dev-admin-token`

Default dev tenant:

- `default`

## Smoke Tests

### Deployment Health

```bash
curl http://localhost:4100/api/healthz
```

Expected result:

- `200`
- a JSON body with runtime, projection, and deployment metadata

### Authenticated Projection Health

```bash
curl http://localhost:4100/api/v1/projections/health \
  -H "Authorization: Bearer dev-reader-token" \
  -H "x-tenant-id: default"
```

### Authenticated Replay Admission

```bash
curl -X POST http://localhost:4100/api/v1/admin/replays \
  -H "Authorization: Bearer dev-admin-token" \
  -H "x-tenant-id: default" \
  -H "content-type: application/json" \
  -d '{"mode":"catch_up","projection":"trace_summary","reason":"smoke test"}'
```

## Readiness Expectations

The service should be considered ready when:

- `/api/healthz` returns `200`
- Phoenix request IDs are being assigned
- the event store can reach Postgres
- projector health can read durable cursors and digests
- no unexpected replay jobs are stuck in `queued` or `running`

## Liveness Expectations

The service is still alive if Phoenix is answering requests, but it may not be healthy for product traffic if:

- Postgres is unavailable
- projector workers are failing repeatedly
- projection lag is unbounded
- replay jobs are stuck or failing

Use `GET /api/v1/projections/health` and the Phase 4 projector runtime guidance together when diagnosing those states.

## Opt-In End-To-End Test

The repo includes a Postgres-backed HTTP end-to-end test scaffold under:

- `beam/apps/dg_web/test/decision_graph_web/controllers/api_service_e2e_test.exs`

Run it only when local Postgres is available:

```bash
set DG_RUN_SERVICE_E2E=1
mix test apps/dg_web/test/decision_graph_web/controllers/api_service_e2e_test.exs
```

## Operator Notes

- replay and rebuild requests require a `reason`
- rebuild is disabled by default outside dev/test unless explicitly enabled
- replay status and cancel are tenant-scoped even when a caller knows a raw `job_id`
