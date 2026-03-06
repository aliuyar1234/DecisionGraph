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

### Active Execution Plans Location

Active execution plans remain in the repo root during the transformation.

Examples:

- `DECISIONGRAPH_BEAM_MASTERPLAN.md`
- `DECISIONGRAPH_PHOENIX_ARCHITECTURE.md`
- `PHASE_0_EXECUTION_PLAN.md`
- `PHASE_1_EXECUTION_PLAN.md`

Reason:

- these are active program-management artifacts, not long-lived end-user docs
- root placement keeps them visible while the transformation is underway

## Intended Future Layout

```text
/
|-- docs/
|   |-- architecture/
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
|-- DECISIONGRAPH_BEAM_MASTERPLAN.md
|-- DECISIONGRAPH_PHOENIX_ARCHITECTURE.md
|-- PHASE_0_EXECUTION_PLAN.md
|-- PHASE_1_EXECUTION_PLAN.md
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

## Rules

- do not move the Python reference implementation during early migration phases
- do not hide active execution plans inside deep docs directories while they are still active
- do not introduce umbrella app names that conflict with the public brand
- prefer clarity and migration safety over elegance during the transition
