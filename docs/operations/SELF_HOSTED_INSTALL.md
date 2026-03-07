# Self-Hosted Install

## Purpose

This guide describes the first supported DecisionGraph self-hosted install path.

The supported path today is source-based:

- clone the repository
- run PostgreSQL locally or on a trusted nearby host
- start the BEAM umbrella from `beam/`

## What Is Mandatory

You need:

- a DecisionGraph repository checkout
- Elixir `~> 1.19`
- a compatible OTP release
- PostgreSQL 16 reachable from the BEAM node

Helpful but optional:

- Docker for the repo `postgres` and `otel-collector` services
- `curl` for smoke tests
- a process supervisor for long-running self-hosted installs

## Fastest Local Bootstrap

From the repository root:

```bash
docker compose up postgres otel-collector -d
cd beam
mix setup
set PHX_SERVER=true
iex -S mix
```

Then open:

- `http://localhost:4100`

This is the default local evaluation path.

## Development Auth Defaults

Development config currently includes:

- `dev-reader-token`
- `dev-writer-token`
- `dev-admin-token`

Default development tenant:

- `default`

These defaults are meant for trusted local evaluation.
They should not be treated as a production auth story.

## Production-Oriented Source Deployment

The first supported non-dev deployment is still source-based.
Before exposing the service on a network, set at least:

- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `PHX_HOST`
- `PORT`
- `POOL_SIZE`
- `PHX_SERVER=true`

Then, from `beam/`:

```bash
mix deps.get
mix compile
mix ecto.migrate
mix phx.server
```

Example runtime environment:

```text
MIX_ENV=prod
DATABASE_URL=ecto://decisiongraph:decisiongraph@localhost/decisiongraph_beam_prod
SECRET_KEY_BASE=<long-random-secret>
PHX_HOST=localhost
PORT=4100
POOL_SIZE=10
PHX_SERVER=true
DECISION_GRAPH_DEPLOYMENT_ENV=prod
```

## Service-Account Bootstrap

Today the supported production bootstrap is config-driven.
The repo does not yet ship a first-run account wizard.

For non-dev installs, define service accounts and the operator console actor under `:dg_api` before exposing the system.
The simplest current approach is to add the config in `beam/config/runtime.exs` or another environment-specific config layer you control.

Example config snippet:

```elixir
config :dg_api,
  operator_console_account_id: "admin-main",
  service_accounts: [
    %{
      account_id: "reader-main",
      roles: ["reader"],
      permissions: [],
      tenant_ids: ["default"],
      token: "replace-me-reader"
    },
    %{
      account_id: "writer-main",
      roles: ["writer"],
      permissions: ["workflow_assign", "workflow_review"],
      tenant_ids: ["default"],
      token: "replace-me-writer"
    },
    %{
      account_id: "admin-main",
      roles: ["admin"],
      permissions: [
        "projection_rebuild",
        "projection_replay",
        "workflow_assign",
        "workflow_escalate",
        "workflow_export",
        "workflow_override",
        "workflow_review"
      ],
      tenant_ids: ["default"],
      token: "replace-me-admin"
    }
  ]
```

Current self-hosted expectation:

- use `default` as the first tenant unless you already need logical isolation
- keep replay controls disabled until the operator account is configured
- replace development tokens before any non-local exposure

## Smoke Test Checklist

### Deployment Health

```bash
curl http://localhost:4100/api/healthz
```

Expected:

- `200`

### Projection Health

```bash
curl http://localhost:4100/api/v1/projections/health -H "Authorization: Bearer dev-reader-token" -H "x-tenant-id: default"
```

Expected:

- `200`
- a JSON response with per-projection lag, digest, and status data

### Replay Admission

```bash
curl -X POST http://localhost:4100/api/v1/admin/replays -H "Authorization: Bearer dev-admin-token" -H "x-tenant-id: default" -H "content-type: application/json" -d "{\"mode\":\"catch_up\",\"projection\":\"trace_summary\",\"reason\":\"self-hosted smoke test\"}"
```

Expected:

- `202`

## Bootstrap Validation Checklist

Use this checklist on a clean machine or fresh server bootstrap:

- Postgres starts and accepts connections
- `mix setup` or `mix ecto.migrate` completes without manual fixes
- `/api/healthz` returns `200`
- authenticated projection health returns `200`
- the operator console loads at `/`
- replay admission works with an admin token
- the install path is understandable without reading source files

## Known Limits In The Current Install Story

Current Phase 8 limits are explicit:

- the supported path is source-based, not a packaged release artifact
- the repo ships Docker services for Postgres and OTEL, not an application container image
- auth bootstrap is config-driven, not UI-driven
- clustering and multi-node failover are out of scope for the supported topology

If those limits are acceptable, this is the supported self-hosted path today.
