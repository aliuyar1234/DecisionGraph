# Phase 0 Execution Plan

## Purpose

This file turns Phase 0 from [DECISIONGRAPH_BEAM_MASTERPLAN.md](DECISIONGRAPH_BEAM_MASTERPLAN.md) into an active execution checklist.

This is the first practical step toward the DecisionGraph Elixir/BEAM platform.

Phase 0 is about deciding what we are building and locking the direction tightly enough that Phase 1 and later implementation work do not drift.

## Phase Goal

By the end of Phase 0 we should have:

- a fully approved architecture direction
- a clear product north star
- a clear repo strategy
- clear product personas
- a documented v1 scope for the future platform
- a stable basis for Phase 1 semantic hardening

## Status

Current phase:
- [x] Phase 0 active

Phase complete:
- [x] Phase 0 complete

## Workstreams

Phase 0 is divided into five workstreams:

- product direction
- architecture direction
- repo strategy
- platform scope
- execution readiness

## Workstream 1 - Product Direction

Goal:
- define what kind of product DecisionGraph is becoming

Tasks:
- [x] Write a concise product statement for the end-state platform
- [x] Define the primary problem the platform solves
- [x] Define the top three product differentiators
- [x] Define the intended product category in plain language
- [x] Decide the product is a combination of a developer platform, operator console, compliance and audit product, and decision workflow engine
- [x] Write a short "why this product matters" section for internal alignment

Deliverables:
- [x] North-star product statement in `docs/vision/PRODUCT_NORTH_STAR.md`
- [x] product differentiators list in `docs/vision/PRODUCT_NORTH_STAR.md`
- [x] category definition in `docs/vision/PRODUCT_NORTH_STAR.md`

## Workstream 2 - Architecture Direction

Goal:
- remove ambiguity around Elixir, BEAM, Phoenix, Python, and Gleam

Tasks:
- [x] Officially approve Elixir as the primary BEAM language
- [x] Officially defer Gleam as a non-primary choice
- [x] Officially keep Python as the semantic reference implementation for now
- [x] Officially choose Phoenix as the platform delivery layer
- [x] Decide that Postgres is the primary production datastore
- [x] Confirm that the first BEAM work is platform/runtime work, not a full semantic rewrite
- [x] Write the architecture decision summary in one page
- [x] Define the migration principle: parity before replacement

Deliverables:
- [x] architecture decision record for language/runtime direction in `docs/architecture/ADR_ELIXIR_DIRECTION.md`
- [x] architecture decision record for Python reference semantics in `docs/architecture/ADR_PYTHON_REFERENCE_CORE.md`
- [x] architecture decision record for Phoenix usage in `docs/architecture/ADR_PHOENIX_PLATFORM_ROLE.md`

## Workstream 3 - Repo Strategy

Goal:
- decide how the codebase should evolve structurally

Tasks:
- [x] Decide to keep a monorepo with Python and Elixir together
- [x] Decide the expected top-level structure for the future repo
- [x] Decide the Elixir umbrella will live under `beam/`
- [x] Decide the Python code should stay under `src/decisiongraph`
- [x] Decide naming for future Elixir apps
- [x] Decide naming for the Phoenix app and web modules
- [x] Decide durable docs belong under `docs/` while active execution plans remain in repo root
- [x] Write the intended repo map for future phases

Deliverables:
- [x] repo structure proposal in `docs/architecture/REPO_EVOLUTION_MAP.md`
- [x] BEAM app naming proposal in `docs/architecture/REPO_EVOLUTION_MAP.md`
- [x] documented module/repo map in `docs/architecture/REPO_EVOLUTION_MAP.md`

## Workstream 4 - Platform Scope

Goal:
- define the target product boundary clearly enough to avoid unfocused implementation

Tasks:
- [x] Define the future platform's primary user personas
- [x] Define what each persona needs from the product
- [x] Define the minimum credible v1 platform feature set
- [x] Define what is explicitly out of scope for v1
- [x] Define what belongs after v1
- [x] Decide hosted cloud is a later phase rather than a near-term requirement
- [x] Decide self-hosted enterprise support is required from the start
- [x] Decide logical multi-tenancy is required in the first platform release
- [x] Define the first impressive demo scenario the platform should support

Deliverables:
- [x] persona definitions in `docs/product/PERSONAS.md`
- [x] v1 scope in `docs/product/V1_PLATFORM_SCOPE.md`
- [x] out-of-scope list in `docs/product/V1_PLATFORM_SCOPE.md`
- [x] demo scenario definition in `docs/product/DEMO_SCENARIO.md`

## Workstream 5 - Execution Readiness

Goal:
- make sure Phase 1 can begin cleanly after Phase 0

Tasks:
- [x] Identify which current Python contracts must be frozen in Phase 1
- [x] Identify which current docs need to become semantic reference docs
- [x] Identify which test suites will become parity harness inputs
- [x] Define what "semantic parity" means for the BEAM migration
- [x] Decide which fixtures will be used as initial cross-language reference data
- [x] Decide the order of Phase 1 work packages
- [x] Create the Phase 1 execution plan
- [x] Define the handoff criteria from Phase 0 to Phase 1

Deliverables:
- [x] Phase 1 readiness checklist in `PHASE_1_EXECUTION_PLAN.md`
- [x] semantic parity definition in `docs/architecture/ADR_PYTHON_REFERENCE_CORE.md` and `PHASE_1_EXECUTION_PLAN.md`
- [x] Phase 1 entry criteria in `PHASE_1_EXECUTION_PLAN.md`

## Concrete Outputs Required Before Phase 0 Can Close

These are required outputs, not optional notes:

- [x] `docs/vision/PRODUCT_NORTH_STAR.md`
- [x] `docs/architecture/ADR_ELIXIR_DIRECTION.md`
- [x] `docs/architecture/ADR_PYTHON_REFERENCE_CORE.md`
- [x] `docs/architecture/ADR_PHOENIX_PLATFORM_ROLE.md`
- [x] `docs/architecture/REPO_EVOLUTION_MAP.md`
- [x] `docs/product/PERSONAS.md`
- [x] `docs/product/V1_PLATFORM_SCOPE.md`
- [x] `docs/product/DEMO_SCENARIO.md`
- [x] `PHASE_1_EXECUTION_PLAN.md`

## Recommended Order

Recommended sequence:

1. Finalize architecture direction
2. Finalize product north star
3. Finalize personas and v1 scope
4. Finalize repo evolution map
5. Finalize Phase 1 readiness definition

## Decisions To Lock In This Phase

These decisions should be considered mandatory Phase 0 decisions:

- [x] Elixir is the primary BEAM language
- [x] Gleam is not the primary path
- [x] Phoenix is the product and operator delivery layer
- [x] Python remains the reference semantics core for now
- [x] Postgres is the production primary store for the future platform
- [x] the BEAM transformation is incremental, not a big-bang rewrite
- [x] the project will target a serious operator-grade product, not just an SDK refresh

## Exit Criteria

Phase 0 is complete only when:

- [x] product direction is documented clearly
- [x] architecture direction is documented clearly
- [x] repo evolution path is documented clearly
- [x] v1 scope is documented clearly
- [x] demo scenario is documented clearly
- [x] Phase 1 can start without foundational ambiguity

## Immediate Next Actions

Recommended immediate actions from this plan:

- [x] create `docs/vision`
- [x] create `docs/architecture`
- [x] create `docs/product`
- [x] write the three architecture ADRs
- [x] write the product north-star doc
- [x] write personas and v1 scope docs
- [x] write `PHASE_1_EXECUTION_PLAN.md`

## Completion Summary

Phase 0 is complete. The key outputs are:

- `docs/vision/PRODUCT_NORTH_STAR.md`
- `docs/architecture/ADR_ELIXIR_DIRECTION.md`
- `docs/architecture/ADR_PYTHON_REFERENCE_CORE.md`
- `docs/architecture/ADR_PHOENIX_PLATFORM_ROLE.md`
- `docs/architecture/REPO_EVOLUTION_MAP.md`
- `docs/product/PERSONAS.md`
- `docs/product/V1_PLATFORM_SCOPE.md`
- `docs/product/DEMO_SCENARIO.md`
- `PHASE_1_EXECUTION_PLAN.md`

## Notes

Rules for this phase:

- do not start implementing Elixir runtime code yet
- do not start Phoenix bootstrap yet
- do not attempt semantic rewrites yet
- use this phase to remove strategic ambiguity, not to chase momentum for its own sake
