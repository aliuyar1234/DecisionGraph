# Self-Hosted Install

## Purpose

This guide describes the first supported DecisionGraph self-hosted install path.

The supported path today is source-first, with an optional packaged OTP release built from the same repo:

- clone the repository
- run PostgreSQL locally or on a trusted nearby host
- start the BEAM umbrella from `beam/`
- optionally seed the curated `release-demo` tenant for the Phase 10 operator showcase

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

Default development tenants:

- `default`
- `release-demo`

These defaults are meant for trusted local evaluation.
They should not be treated as a production auth story.

## Release Demo Bootstrap

Once Phoenix is running, seed the curated operator demo from a second terminal:

```bash
cd beam
mix dg.demo.seed --output ../.tmp/phase10-demo-report.json
```

This creates a realistic evaluation tenant named `release-demo` with:

- an approved precedent trace
- a live escalated exception review
- an incident review workflow

Primary console routes:

- `http://localhost:4100/?tenant=release-demo&trace_id=trace-live-renewal-002&workflow_id=trace-live-renewal-002:exception:ex-live-renewal-002`
- `http://localhost:4100/?tenant=release-demo&trace_id=trace-incident-review-003&workflow_id=trace-incident-review-003:trace_review:incident_triage`

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

Today the preferred production bootstrap is file-driven.
The repo does not yet ship a UI first-run wizard, but it no longer requires hand-authoring service-account config in Elixir files.

Generate a bootstrap file:

```bash
cd beam
mix dg.accounts.bootstrap --output ../.tmp/service-accounts.json
```

Then point the runtime at it:

```text
DECISION_GRAPH_SERVICE_ACCOUNTS_FILE=/absolute/path/to/service-accounts.json
DECISION_GRAPH_OPERATOR_ACCOUNT_ID=admin-main
```

For packaged OTP releases, you can also place the file at:

```text
config/service-accounts.json
```

inside the extracted release root. The release runtime will load that path automatically.

The generated JSON format is:

```json
{
  "operator_console_account_id": "admin-main",
  "service_accounts": [
    {
      "account_id": "reader-main",
      "roles": ["reader"],
      "permissions": [],
      "tenant_ids": ["default"],
      "tokens": ["replace-me-reader"]
    }
  ]
}
```

Current self-hosted expectation:

- use `default` as the first tenant unless you already need logical isolation
- keep replay controls disabled until the operator account is configured
- replace development tokens before any non-local exposure

Token rotation rule:

- each account may carry a `tokens` list
- keep old and new tokens together during the overlap window
- remove the old token only after clients have moved

## Smoke Test Checklist

### Deployment Health

```bash
curl http://localhost:4100/api/healthz
```

Expected:

- `200`

### Projection Health

```bash
curl http://localhost:4100/api/v1/projections/health -H "Authorization: Bearer dev-reader-token" -H "x-tenant-id: release-demo"
```

Expected:

- `200`
- a JSON response with per-projection lag, digest, and status data

### Replay Admission

```bash
curl -X POST http://localhost:4100/api/v1/admin/replays -H "Authorization: Bearer dev-admin-token" -H "x-tenant-id: release-demo" -H "content-type: application/json" -d "{\"mode\":\"catch_up\",\"projection\":\"trace_summary\",\"reason\":\"self-hosted smoke test\"}"
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

## Release-Candidate Validation Command

For the supported self-hosted evaluation path, the one-command release validator is:

```bash
cd beam
mix dg.release.validate --output ../.tmp/phase10-release-validation.json
```

This command starts the real HTTP runtime, seeds the `release-demo` tenant, and records validation evidence for the current release candidate.

## OTP Release Packaging

Build the packaged BEAM release:

```bash
cd beam
mix release decisiongraph_beam
```

The packaged release lives under:

- `beam/_build/prod/rel/decisiongraph_beam`

Run migrations from the packaged release:

```bash
cd beam
_build/prod/rel/decisiongraph_beam/bin/decisiongraph_beam eval "DecisionGraph.Store.Release.migrate()"
```

Start the packaged release:

```bash
cd beam
_build/prod/rel/decisiongraph_beam/bin/decisiongraph_beam start
```

## Container Image Build

Build the repo-provided image from the packaged OTP release:

```bash
cd beam
mix release decisiongraph_beam
docker build -f Dockerfile -t decisiongraph-beam:local _build/prod/rel
```

If you prefer a source-building Docker path that compiles the release inside Docker, use:

```bash
cd beam
docker build -f Dockerfile.build -t decisiongraph-beam:source .
```

## Known Limits In The Current Install Story

Current Phase 8 limits are explicit:

- there is no hosted SaaS path
- there is no prebuilt published app image yet; the repo now ships `beam/Dockerfile` and `beam/Dockerfile.build`
- there is no prebuilt published OTP release asset yet; the repo now supports `mix release decisiongraph_beam`
- auth bootstrap is file-driven or env-driven, not UI-driven
- clustering and multi-node failover are out of scope for the supported topology

If those limits are acceptable, this is the supported self-hosted path today.
