# ADR: Keep Python as the Reference Semantics Core During the BEAM Transition

## Status

Accepted

## Date

2026-03-06

## Context

DecisionGraph already has a tested Python implementation covering:

- event envelope construction
- schema validation
- idempotency behavior
- append ordering and trace sequencing
- deterministic projections
- digest generation
- query behavior

The BEAM move is intended to improve platform runtime behavior and product ambition, not to throw away the existing semantic correctness.

The main migration risk is not syntax or performance. It is semantic drift.

## Decision

The Python implementation under `src/decisiongraph` will remain the reference semantics core until the Elixir platform proves parity.

This means:

- Python defines the current truth for event shapes and invariants
- Python golden fixtures and digest outputs are authoritative reference assets
- Elixir services and runtime components may be introduced before a full semantic rewrite
- no Elixir implementation becomes the authoritative semantic core until parity is explicitly demonstrated and accepted

The Phase 1 reference assets for this decision are now checked in at:

- `docs/reference/`
- `tests/golden/reference_fixture_bundle.json`

The baseline checkpoint name for this reference package is:

- `semantic-reference-python-v1`

## What Must Reach Parity Before Replacement

At minimum:

- event envelope contract
- payload shape rules for supported event types
- idempotency semantics
- trace sequencing and monotonicity behavior
- projection cursor behavior
- projection table semantics
- deterministic digests
- query ordering and filtering behavior
- staleness and out-of-date safeguards

## Rationale

This decision preserves the strongest part of the current project while still allowing aggressive platform evolution.

It lets us:

- build BEAM runtime value early
- avoid a risky big-bang rewrite
- compare Elixir outputs against a known-good oracle
- ship platform improvements before semantic porting is complete

## Consequences

### Positive

- migration risk is lower
- parity can be measured instead of argued about
- the current test suite and golden fixtures become strategic assets

### Negative

- some logic may temporarily exist in both ecosystems
- phase planning must respect the difference between runtime ownership and semantic ownership
- platform implementation speed is constrained by the parity discipline we are choosing

## Replacement Rule

The Elixir side may replace Python as the authoritative semantic core only after:

- parity criteria are defined in advance
- fixture and digest comparisons are automated
- divergences are either removed or explicitly accepted
- an explicit architecture decision records the handoff
