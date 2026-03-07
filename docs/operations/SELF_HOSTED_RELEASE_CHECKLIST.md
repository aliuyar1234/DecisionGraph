# Self-Hosted Release Checklist

## Purpose

This checklist defines what must be true before calling a DecisionGraph GitHub release self-hosted-ready.

## Release Artifacts

The supported self-hosted release artifacts today are:

- a git tag or GitHub source archive for this repository
- the `beam/` umbrella application
- the repo `docker-compose.yml` for Postgres and optional OTEL
- operator docs and runbooks under `docs/`

Current non-artifacts:

- there is no packaged application container image
- there is no generated OTP release bundle checked into this repo

## Supported Entry Paths

Supported:

- source checkout plus local or nearby Postgres
- source checkout plus Docker-managed Postgres from `docker-compose.yml`

Optional:

- Docker-managed OTEL collector

Not currently supported:

- full Docker-only app deployment using a repository-provided app image
- multi-node clustered release packaging

## Pre-Release Gates

- install docs reflect the current repo reality
- `mix setup` succeeds on the supported source path
- `/api/healthz` and authenticated projection health smoke checks pass
- backup artifact creation succeeds
- restore drill succeeds against a throwaway database
- controlled restart drill succeeds
- projector integration recovery suite passes
- authenticated service E2E suite passes
- current capacity and resilience notes are updated
- unsupported topologies remain documented explicitly

## Release Validation Commands

The minimum validation set for the current self-hosted release posture is:

```bash
docker compose up postgres otel-collector -d
cd beam
mix setup
mix test apps/dg_projector/test/decision_graph/projector/integration_test.exs
set DG_RUN_SERVICE_E2E=1
set MIX_ENV=test
mix test apps/dg_web/test/decision_graph_web/controllers/api_service_e2e_test.exs
```

Also run the documented:

- backup and restore drill
- controlled restart drill
- local-hosting benchmark captures

## Release Notes Inputs

Every self-hosted release should mention:

- migration expectations
- backup requirement before upgrade
- any auth or config changes
- known unsupported topologies
- benchmark or resilience regressions if any

## Phase 8 Position

This checklist is intentionally matched to the current source-based self-hosted story.
If the project later ships OTP releases or containerized app artifacts, this checklist should expand rather than pretending those paths are already supported.
