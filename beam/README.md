# DecisionGraph BEAM Umbrella

This umbrella bootstraps the Elixir side of DecisionGraph without replacing the Python semantic oracle.

## Apps

- `dg_domain`: shared structs and runtime context conventions
- `dg_store`: Ecto/Postgres repo bootstrap
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
```

`mix check` currently runs formatter validation, Credo, and the umbrella test suite. Dialyzer runs as its own gate locally and in CI.

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
