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
```

`mix check` currently runs formatter validation, Credo, and the umbrella test suite. Dialyzer runs as its own gate locally and in CI.

## Phase 3 Store Commands

Create and migrate the BEAM event-store database:

```bash
cd beam
set MIX_ENV=test
mix cmd --app dg_store mix ecto.setup
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

## CI Expectations

The repo-level BEAM workflow lives in `.github/workflows/beam.yml` and runs:

- `mix format --check-formatted`
- `mix credo --strict`
- `mix test`
- `mix dialyzer`

Phase 3 references:

- store contract: [`docs/architecture/BEAM_STORE_CONTRACT.md`](../docs/architecture/BEAM_STORE_CONTRACT.md)
- benchmark baseline: [`docs/benchmarks/PHASE_3_STORE_BASELINE.md`](../docs/benchmarks/PHASE_3_STORE_BASELINE.md)
