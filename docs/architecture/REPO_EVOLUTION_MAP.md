# Repo Evolution Map

## Purpose

This document defines how the repository should evolve from a Python-first library into a Python-plus-Elixir platform codebase.

It is the structural answer to the Phase 0 question:

How do we grow this project without destabilizing the strong reference implementation we already have?

## Chosen Strategy

DecisionGraph will remain a monorepo.

The repo will keep:

- the current Python implementation as the reference semantics core
- planning and strategy documents in-repo
- a future Elixir umbrella for platform runtime and Phoenix delivery

This is preferred over splitting into separate repos because the migration depends on:

- shared fixtures
- shared parity definitions
- shared architecture records
- close coordination between reference semantics and runtime implementation

## Structural Decisions

### Python Location

The Python reference implementation stays under:

- `src/decisiongraph`
- `tests`

This is stable and should not be moved during early phases.

### Elixir Umbrella Location

The future Elixir umbrella should live under:

- `beam/`

Reason:

- it avoids destabilizing the current Python root and packaging setup too early
- it makes toolchain boundaries clear
- it allows incremental adoption without pretending the repo has already been fully re-centered around Elixir

### Durable Documentation Location

Durable strategy and architecture outputs belong under:

- `docs/vision`
- `docs/architecture`
- `docs/product`
- `docs/reference`
- `docs/plans`

### Execution Plans Location

The BEAM master plan and phase execution plans now live under:

Examples:

- `docs/plans/DECISIONGRAPH_BEAM_MASTERPLAN.md`
- `docs/plans/PHASE_0_EXECUTION_PLAN.md`
- `docs/plans/PHASE_1_EXECUTION_PLAN.md`

Reason:

- these are durable program-history artifacts now that the initial platform buildout is complete
- keeping them under `docs/plans` keeps the repository root cleaner without losing the implementation record

The Phoenix architecture record also now lives with the rest of the architecture docs:

- `docs/architecture/DECISIONGRAPH_PHOENIX_ARCHITECTURE.md`

## Intended Future Layout

```text
/
|-- docs/
|   |-- architecture/
|   |   |-- DECISIONGRAPH_PHOENIX_ARCHITECTURE.md
|   |-- plans/
|   |-- product/
|   |-- reference/
|   |-- vision/
|-- src/
|   |-- decisiongraph/
|-- tests/
|-- beam/
|   |-- apps/
|   |   |-- dg_domain/
|   |   |-- dg_store/
|   |   |-- dg_projector/
|   |   |-- dg_api/
|   |   |-- dg_web/
|   |   |-- dg_observability/
|   |-- config/
|   |-- mix.exs
```

## Naming Decisions

### Umbrella App Names

Chosen internal app names:

- `dg_domain`
- `dg_store`
- `dg_projector`
- `dg_api`
- `dg_web`
- `dg_observability`

### Phoenix Web Module

Chosen web module name:

- `DecisionGraphWeb`

### Public Brand Name

Keep the public product and repo name as:

- `DecisionGraph`

## Evolution by Phase

### Phase 0

- create durable direction docs
- create execution plans
- do not add Elixir code yet

### Phase 1

- strengthen Python reference semantics
- add reference docs and parity definitions
- add exportable fixture bundles and semantic baseline assets
- keep repo structure otherwise stable

### Phase 2

- add `beam/` umbrella
- wire Elixir CI, linting, and local dev flows

### Phase 3 to Phase 5

- add store, projector, and Phoenix delivery apps
- keep Python as semantic reference

### Phase 6 and Beyond

- deepen operator UI, workflows, and multi-tenant runtime behavior
- reconsider whether the repo should be re-centered only after the BEAM platform is stable and proven
- move completed transformation plans out of the repo root once the first release is cut

## Rules

- do not move the Python reference implementation during early migration phases
- keep execution plans easy to find, but move completed plan history under `docs/plans` once the release program stabilizes
- do not introduce umbrella app names that conflict with the public brand
- prefer clarity and migration safety over elegance during the transition
