# Self-Hosted Release Checklist

## Purpose

This checklist defines what must be true before calling a DecisionGraph GitHub release self-hosted-ready.

## Release Artifacts

The supported self-hosted release artifacts today are:

- a git tag or GitHub source archive for this repository
- the `beam/` umbrella application
- a packaged OTP release built from `mix release decisiongraph_beam`
- a signed packaged OTP release tarball attached by the tagged release workflow
- a tagged GHCR image built from `beam/Dockerfile`
- a repo-provided container build path via `beam/Dockerfile`
- an optional source-building container path via `beam/Dockerfile.build`
- the repo `docker-compose.yml` for Postgres and optional OTEL
- operator docs and runbooks under `docs/`

## Supported Entry Paths

Supported:

- source checkout plus local or nearby Postgres
- source checkout plus Docker-managed Postgres from `docker-compose.yml`
- packaged OTP release plus local or nearby Postgres
- tagged GHCR image plus operator-supplied runtime env and service-account bootstrap file
- repo-built container image plus operator-supplied runtime env and service-account bootstrap file

Optional:

- Docker-managed OTEL collector

Not currently supported:

- full Docker-only app deployment using a repository-provided app image
- multi-node clustered release packaging

## Pre-Release Gates

- install docs reflect the current repo reality
- service-account bootstrap is reproducible through `mix dg.accounts.bootstrap`
- `mix setup` succeeds on the supported source path
- `mix release decisiongraph_beam` succeeds
- `docker build -f Dockerfile -t decisiongraph-beam:release _build/prod/rel` succeeds from `beam/` after the release is built
- the tagged release workflow publishes the signed OTP tarball plus GHCR image metadata successfully
- `/api/healthz` and authenticated projection health smoke checks pass
- backup artifact creation succeeds
- restore drill succeeds against a throwaway database
- controlled restart drill succeeds
- projector integration recovery suite passes
- authenticated service E2E suite passes
- current capacity and resilience notes are updated
- unsupported topologies remain documented explicitly

## Release Evidence Record

Every serious self-hosted release should record:

- release candidate version or tag
- validation host or topology
- database version used for validation
- backup and restore drill status
- restart or recovery drill status
- parity or determinism evidence status
- known limitations reviewed

## Sign-Off

Before release, capture explicit sign-off from:

- release owner
- runtime owner
- reference or parity owner
- docs or showcase owner

Minimum release questions:

- is the supported topology validated for this tag
- are upgrade and rollback instructions current
- are unsupported deployment paths stated clearly
- are release notes and known limitations ready to publish

## Support and Hotfix Readiness

Before release, confirm:

- GitHub issues and discussions are the published support channels
- first-release support expectations are stated honestly in release notes or docs
- critical hotfix owners are identified
- rollback path is clearer than the hotfix path if data integrity is at risk

## Release Validation Commands

The minimum validation set for the current self-hosted release posture is:

```bash
docker compose up postgres otel-collector -d
cd beam
mix setup
set DG_RUN_SERVICE_E2E=1
set MIX_ENV=test
mix test apps/dg_projector/test/decision_graph/projector/parity_test.exs
mix test apps/dg_store/test/decision_graph/store/parity_test.exs
mix test apps/dg_projector/test/decision_graph/projector/query_parity_test.exs
mix test apps/dg_web/test/decision_graph_web/controllers/api_service_e2e_test.exs
set MIX_ENV=dev
mix dg.demo.seed --output ../.tmp/phase10-demo-report.json
python ../scripts/beam_docs_snippets_check.py --artifact-dir ../.tmp/beam-docs-snippets
mix dg.release.validate --output ../.tmp/phase10-release-validation.json --summary-output ../.tmp/phase10-release-validation.md
set MIX_ENV=prod
mix release decisiongraph_beam
docker build -f Dockerfile -t decisiongraph-beam:release _build/prod/rel
```

Also run the documented:

- backup and restore drill
- controlled restart drill
- local-hosting benchmark captures
- and archive the generated Phase 10 JSON evidence reports with the release record

## Release Notes Inputs

Every self-hosted release should mention:

- migration expectations
- backup requirement before upgrade
- any auth or config changes
- known unsupported topologies
- known limitations and sharp edges that remain acceptable
- benchmark or resilience regressions if any

## Phase 10 Position

This checklist is intentionally matched to the current self-hosted story:

- source-first runtime
- packaged OTP release path
- release-derived Docker build path

This checklist should expand again if the release workflow later adds stronger distribution guarantees such as broader installer formats or multi-node packaging.
