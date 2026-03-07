# Phase 2 Execution Plan

## Purpose

This file turns Phase 2 from [DECISIONGRAPH_BEAM_MASTERPLAN.md](DECISIONGRAPH_BEAM_MASTERPLAN.md) into an active execution checklist.

Phase 2 is about bootstrapping the Elixir platform cleanly without rewriting the Python semantic core.

## Phase Goal

By the end of Phase 2 we should have:

- a real `beam/` umbrella in the repo
- clean OTP app boundaries
- working Elixir quality gates
- a local Beam development loop
- baseline observability and logging conventions
- architectural docs that make process ownership obvious

## Status

Current phase:
- [x] Phase 2 active

Phase complete:
- [x] Phase 2 complete

## Workstreams

- umbrella foundation
- tooling and quality
- runtime boundaries
- local development and config
- docs and operating model

## Workstream 1 - Umbrella Foundation

Goal:
- create the actual Elixir home for the platform

Tasks:
- [x] create `beam/` umbrella root
- [x] create `dg_domain`
- [x] create `dg_store`
- [x] create `dg_projector`
- [x] create `dg_api`
- [x] create `dg_web`
- [x] create `dg_observability`
- [x] define baseline dependencies and app wiring

Deliverables:
- [x] umbrella root in `beam/`
- [x] app boundaries matching the Phase 0 repo map

## Workstream 2 - Tooling and Quality

Goal:
- make the Elixir side enforceable from day one

Tasks:
- [x] configure formatter inputs and aliases
- [x] add Credo
- [x] add Dialyzer
- [x] add ExUnit property testing for concurrency-sensitive runtime behavior
- [x] add umbrella test conventions and helper structure
- [x] add CI jobs for compile, lint, dialyzer, and tests

Deliverables:
- [x] formatter config
- [x] static analysis config
- [x] first property-based tests
- [x] CI coverage for the Beam side

## Workstream 3 - Runtime Boundaries

Goal:
- make ownership of long-lived processes explicit

Tasks:
- [x] wire the store Repo under `dg_store`
- [x] wire projector registries and supervisors under `dg_projector`
- [x] wire web endpoint and PubSub under `dg_web`
- [x] keep `dg_domain` mostly pure
- [x] keep `dg_api` thin in Phase 2
- [x] wire observability startup and telemetry attachments under `dg_observability`

Deliverables:
- [x] supervision layout implemented in code
- [x] supervision layout documented in `docs/architecture/BEAM_SUPERVISION_TREE.md`
- [x] ownership rules documented in `docs/architecture/BEAM_PROCESS_OWNERSHIP.md`

## Workstream 4 - Local Development and Config

Goal:
- make local Beam work repeatable without guesswork

Tasks:
- [x] add Postgres development orchestration for the Beam side
- [x] add any baseline telemetry/export dependencies needed locally
- [x] define shared compile-time config in umbrella config
- [x] define `dev`, `test`, and `prod` env config files
- [x] define deploy-time values in `runtime.exs`
- [x] define the staging rule: staging should differ by runtime env vars, not by a divergent app structure

Deliverables:
- [x] local Beam dev orchestration
- [x] config strategy implemented in `beam/config/`

## Config Strategy Summary

Phase 2 should use this config split:

- `beam/config/config.exs` for shared compile-time defaults
- `beam/config/dev.exs` for local developer behavior
- `beam/config/test.exs` for deterministic CI/test settings
- `beam/config/prod.exs` for production compile-time defaults
- `beam/config/runtime.exs` for secrets, URLs, ports, and exporter endpoints

Staging should reuse the production code path and differ only through runtime configuration.

## Workstream 5 - Docs and Operating Model

Goal:
- make the Beam foundation easy to understand before feature pressure arrives

Tasks:
- [x] write the supervision-tree doc
- [x] write the process-ownership doc
- [x] create this execution plan
- [x] document Beam developer commands and bootstrap flow
- [x] document Beam CI expectations

Deliverables:
- [x] `docs/architecture/BEAM_SUPERVISION_TREE.md`
- [x] `docs/architecture/BEAM_PROCESS_OWNERSHIP.md`
- [x] `PHASE_2_EXECUTION_PLAN.md`

## Exit Criteria

Phase 2 is complete only when:

- [x] the repo builds Python and Elixir surfaces side by side
- [x] the Elixir umbrella has stable app boundaries
- [x] Elixir lint, type analysis, and tests run in CI
- [x] local Postgres-backed Beam development works predictably
- [x] process ownership is documented clearly enough that later phases do not guess

## Immediate Next Actions

- [x] scaffold the umbrella in `beam/`
- [x] wire baseline dependencies and supervisors
- [x] add Beam CI jobs
- [x] add local orchestration and runtime config
- [x] validate compile, lint, dialyzer, and tests

## Completion Summary

Phase 2 completed with these concrete outputs:

- [x] `beam/` umbrella with `dg_domain`, `dg_store`, `dg_projector`, `dg_api`, `dg_web`, and `dg_observability`
- [x] Phoenix + LiveView delivery shell with a baseline health controller and dashboard
- [x] projector runtime shell with dynamic worker supervision and replay task ownership
- [x] local Postgres and OpenTelemetry bootstrap via `docker-compose.yml`
- [x] Elixir CI workflow in `.github/workflows/beam.yml`
- [x] Beam bootstrap guide in `beam/README.md`
- [x] supervision and process-ownership architecture docs in `docs/architecture/`

Validation completed during Phase 2:

- [x] `mix compile`
- [x] `mix format --check-formatted`
- [x] `mix credo --strict`
- [x] `mix dialyzer`
- [x] `mix test`
- [x] `uv run pytest -q`
- [x] `uv run ruff check src demo scripts tests`
- [x] `uv run mypy src`
- [x] `uv run lint-imports`
