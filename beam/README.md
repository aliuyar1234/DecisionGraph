# DecisionGraph BEAM Umbrella

This umbrella bootstraps the Elixir side of DecisionGraph without replacing the Python semantic oracle.

## Apps

- `dg_domain`: shared structs and runtime context conventions
- `dg_store`: Postgres event store, migrations, parity tests, and benchmark task
- `dg_projector`: supervised projector worker/runtime shell
- `dg_api`: service-boundary modules shared by delivery layers
- `dg_web`: Phoenix + LiveView delivery shell
- `dg_observability`: telemetry, OpenTelemetry baseline, and request/log context

## Commands

```bash
cd beam
mix setup
mix check
mix credo --strict
mix dialyzer
mix test
mix test apps/dg_store/test
python ../scripts/beam_docs_snippets_check.py --artifact-dir ../.tmp/beam-docs-snippets
```

`mix check` currently runs formatter validation, Credo, and the umbrella test suite. Dialyzer runs as its own gate locally and in CI.

## Phase 3 Store Commands

Create and migrate the BEAM event-store database:

```bash
cd beam
set MIX_ENV=test
mix do --app dg_store ecto.setup
```

Run the dedicated store suite:

```bash
cd beam
mix test apps/dg_store/test
```

Run the Phase 3 baseline benchmark:

```bash
cd beam
set MIX_ENV=test
mix dg.store.bench --traces 100 --events-per-trace 8 --batch-size 250 --payload-bytes 512
```

The benchmark uses the Phase 3 Postgres event log and `dg_projection_cursors` table only. Projection materialization is still Phase 4 work.

## Local Runtime

Start dependencies from the repo root:

```bash
docker compose up postgres otel-collector -d
```

Then run the BEAM shell:

```bash
cd beam
set PHX_SERVER=true
iex -S mix
```

The web shell listens on `http://localhost:4100`.

## Phase 10 Demo And Release Validation

Seed the curated self-hosted release demo from a second terminal:

```bash
cd beam
mix dg.demo.seed --output ../.tmp/phase10-demo-report.json
```

That seeds the `release-demo` tenant with:

- `trace-precedent-renewal-001`
- `trace-live-renewal-002`
- `trace-incident-review-003`

The main seeded console routes are:

- `http://localhost:4100/?tenant=release-demo&trace_id=trace-live-renewal-002&workflow_id=trace-live-renewal-002:exception:ex-live-renewal-002`
- `http://localhost:4100/?tenant=release-demo&trace_id=trace-incident-review-003&workflow_id=trace-incident-review-003:trace_review:incident_triage`

Validate the supported release path with the real HTTP runtime:

```bash
cd beam
mix dg.release.validate --output ../.tmp/phase10-release-validation.json --summary-output ../.tmp/phase10-release-validation.md
```

For a quieter staging-style validation pass that reuses existing seeded data:

```bash
cd beam
mix dg.release.validate --seed-mode reuse --quiet --output ../.tmp/phase10-release-validation.json --summary-output ../.tmp/phase10-release-validation.md
```

That release validator checks:

- `/api/healthz`
- operator console HTML for the seeded route
- authenticated projection health
- authenticated trace read
- authenticated workflow list and export
- replay admission and completion

Generate a production-style bootstrap file:

```bash
cd beam
mix dg.accounts.bootstrap --output ../.tmp/service-accounts.json
```

Once the Phoenix app is running, `/bootstrap` provides a first-run bootstrap preview plus
token-rotation overlap guidance for the currently configured service accounts.

Build the OTP release artifact:

```bash
cd beam
mix release decisiongraph_beam
```

The packaged release is created under:

- `_build/prod/rel/decisiongraph_beam`

Run migrations from the packaged release:

```bash
cd beam
_build/prod/rel/decisiongraph_beam/bin/decisiongraph_beam eval "DecisionGraph.Store.Release.migrate()"
```

Build the container image:

```bash
cd beam
mix release decisiongraph_beam
docker build -f Dockerfile -t decisiongraph-beam:local _build/prod/rel
```

Tagged GitHub releases now support:

- a signed packaged OTP tarball attached to the GitHub Release
- a prebuilt GHCR image built from `beam/Dockerfile`

That default image packages the already-built OTP release from `_build/prod/rel/decisiongraph_beam` and uses `_build/prod/rel` as the Docker build context.

If you want Docker to compile the BEAM release from source instead, use:

```bash
cd beam
docker build -f Dockerfile.build -t decisiongraph-beam:source .
```

## Self-Hosted Guidance

The first supported self-hosted topology is intentionally narrow:

- one BEAM node
- one Postgres instance
- source-based deployment from this repo, or a packaged OTP release derived from it

Start with:

- [`docs/architecture/SELF_HOSTED_TOPOLOGY.md`](../docs/architecture/SELF_HOSTED_TOPOLOGY.md)
- [`docs/architecture/SINGLE_NODE_RECOVERY.md`](../docs/architecture/SINGLE_NODE_RECOVERY.md)
- [`docs/operations/SELF_HOSTED_INSTALL.md`](../docs/operations/SELF_HOSTED_INSTALL.md)
- [`docs/operations/BACKUP_AND_RESTORE.md`](../docs/operations/BACKUP_AND_RESTORE.md)
- [`docs/operations/UPGRADE_AND_ROLLBACK.md`](../docs/operations/UPGRADE_AND_ROLLBACK.md)
- [`docs/operations/DISASTER_RECOVERY.md`](../docs/operations/DISASTER_RECOVERY.md)
- [`docs/operations/SELF_HOSTED_RELEASE_CHECKLIST.md`](../docs/operations/SELF_HOSTED_RELEASE_CHECKLIST.md)
- [`docs/benchmarks/PHASE_10_RELEASE_VALIDATION.md`](../docs/benchmarks/PHASE_10_RELEASE_VALIDATION.md)
- [`docs/benchmarks/PHASE_8_CAPACITY_MODEL.md`](../docs/benchmarks/PHASE_8_CAPACITY_MODEL.md)
- [`docs/benchmarks/PHASE_8_RESILIENCE_BASELINE.md`](../docs/benchmarks/PHASE_8_RESILIENCE_BASELINE.md)

## CI Expectations

The repo-level BEAM workflow lives in `.github/workflows/beam.yml` and runs:

- `mix format --check-formatted`
- `mix credo --strict`
- `python ../scripts/beam_docs_snippets_check.py --artifact-dir ../.tmp/beam-docs-snippets`
- store, projector, and query parity proofs
- `mix test`
- `mix dialyzer`

Phase 3 references:

- store contract: [`docs/architecture/BEAM_STORE_CONTRACT.md`](../docs/architecture/BEAM_STORE_CONTRACT.md)
- benchmark baseline: [`docs/benchmarks/PHASE_3_STORE_BASELINE.md`](../docs/benchmarks/PHASE_3_STORE_BASELINE.md)
