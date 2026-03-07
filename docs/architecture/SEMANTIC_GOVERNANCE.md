# Semantic Governance

## Purpose

This document closes the governance questions from Phase 9.

It defines:

- who owns semantic changes long term
- what approval rules apply to frozen-core behavior
- how parity infrastructure is maintained
- when the project would ever revisit semantic authority

## Final Phase 9 Governance Decision

As of 2026-03-07:

- Python remains the permanent semantic authority for the frozen Phase 1 reference scope
- BEAM remains the runtime and product delivery authority for the self-hosted platform
- the project is not pursuing a full semantic authority handoff at this time

This means governance must preserve a deliberate split instead of pretending there is only one implementation.

## Ownership Model

Three ownership roles matter for semantic governance.

### 1. Reference-core owner

This role owns the frozen semantic contract under:

- `src/decisiongraph/`
- `docs/reference/`
- `tests/golden/reference_fixture_bundle.json`

Responsibilities:

- review any proposed frozen-core semantic change
- keep the Python reference behavior and docs aligned
- ensure fixture outputs are updated only intentionally

### 2. BEAM parity owner

This role owns the BEAM-side semantic mirrors and parity enforcement under:

- `beam/apps/dg_domain/`
- `beam/apps/dg_store/`
- `beam/apps/dg_projector/`
- BEAM parity suites and digests

Responsibilities:

- keep BEAM runtime behavior aligned with the frozen semantic reference
- classify parity failures as implementation drift, fixture drift, or scope confusion
- update parity coverage when frozen-core behavior changes intentionally

### 3. Release owner

This role owns the final release gate whenever semantics could be affected.

Responsibilities:

- verify the reference docs, fixture bundle, and parity suites moved together
- ensure semantic diffs are classified before release
- reject releases that weaken determinism, ordering, idempotency, or freshness guarantees

One maintainer may hold multiple roles, but the responsibilities must still be performed explicitly.

## Change Approval Rules

Any change that affects the frozen Phase 1 semantic scope must update all relevant artifacts together:

- reference docs in `docs/reference/`
- Python reference behavior and tests
- `tests/golden/reference_fixture_bundle.json`
- BEAM parity suites
- `docs/reference/SEMANTIC_OWNERSHIP_CHANGELOG.md`
- release notes or migration notes if user-visible behavior changes

No frozen-core semantic change is complete until those artifacts are updated together.

## Scope Protection Rules

To keep governance honest:

- BEAM-only workflow and operator features must not be counted as frozen-core parity evidence unless the baseline is intentionally widened
- transport, auth, supervision, and UI changes are not semantic-core changes unless they alter observable frozen-core outcomes
- human-readable error text may differ only if the semantic category and invariant remain the same

## Release Gates

Any release that could affect frozen-core semantics must pass these gates:

- Python reference tests for the affected area
- BEAM parity suites for the affected area
- fixture and digest review
- diff classification review if outputs changed

No release may rely on "close enough" behavior for digest values, ordering, idempotency, trace locking, or stale-read safeguards.

## Parity Infrastructure Upkeep

Long-term maintenance rules for the parity harness live in:

- `docs/operations/PARITY_INFRASTRUCTURE_MAINTENANCE.md`

That document is part of the semantic release gate, not optional background reading.

## Permanent Reference Story

The long-term split after Phase 9 is:

- Python is the semantic oracle, fixture generator, embedded library, CLI, and offline or reference surface
- BEAM is the self-hosted runtime, service API, projector runtime, workflow layer, and operator console platform

This is a stable architecture, not an unfinished migration.

## Revisit Rules

The project may revisit semantic authority only if all of the following are true:

- the product scope changes materially enough that the frozen Phase 1 boundary is no longer sufficient
- maintainers can show concrete product or maintenance benefit from changing authority
- a new ADR explicitly proposes the change
- the parity report, bridge policy, and rollback rules are refreshed before any handoff attempt

Without those conditions, the default remains unchanged: Python stays authoritative.

## Rollback Rule For Any Future Revisit

If a future authority-handoff attempt is ever made, rollback is mandatory if any of the following appear within one release cycle:

- digest or ordering regressions in the frozen scope
- idempotency, trace-sequence, or staleness regressions
- ambiguous local-versus-service behavior for Python users
- inability to explain the new authority model cleanly in docs and release notes

In that case, the project must restore Python as the explicit semantic oracle and record the failed attempt in a new ADR or incident note.

## Gleam Position

Phase 9 re-evaluated Gleam and keeps the earlier stance:

- do not introduce Gleam as a primary implementation language
- do not rewrite existing Elixir or Python semantic code into Gleam for aesthetic reasons
- reconsider Gleam only for a small pure library if it offers clear maintenance leverage after stabilization

Any such reconsideration requires a separate ADR and does not reopen semantic authority by itself.
