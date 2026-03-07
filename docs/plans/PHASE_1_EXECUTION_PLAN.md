# Phase 1 Execution Plan

## Purpose

This file turns Phase 1 from [DECISIONGRAPH_BEAM_MASTERPLAN.md](DECISIONGRAPH_BEAM_MASTERPLAN.md) into an active execution plan.

Phase 1 is about freezing and documenting the Python implementation as the semantic reference layer before any serious BEAM-side replacement work begins.

## Phase Goal

By the end of Phase 1 we should have:

- a clearly frozen semantic reference
- stronger parity-oriented fixtures and tests
- documented invariants that the Elixir side must preserve
- exportable reference assets for cross-language comparison
- a baseline release or checkpoint that future BEAM work can target

## Workstreams

- contract freeze
- parity assets
- reference documentation
- cross-language parity preparation
- semantic baseline release

## Workstream 1 - Contract Freeze

Goal:
- lock the current semantic behavior into explicit contracts

Tasks:
- [x] Freeze the event envelope contract formally
- [x] Freeze payload shape rules for current event types
- [x] Freeze idempotency semantics and retry behavior
- [x] Freeze trace sequencing and monotonicity rules
- [x] Freeze staleness and projection cursor rules
- [x] Freeze query ordering guarantees
- [x] Freeze digest semantics and output expectations

Deliverables:
- [x] `docs/reference/EVENT_ENVELOPE_CONTRACT.md`
- [x] `docs/reference/PAYLOAD_SHAPE_MATRIX.md`
- [x] `docs/reference/QUERY_AND_ORDERING_INVARIANTS.md`
- [x] `docs/reference/DIGEST_INVARIANTS.md`

## Workstream 2 - Parity Assets

Goal:
- expand the reference data that later Elixir tests will consume

Tasks:
- [x] Expand golden fixtures to cover approvals, exceptions, precedents, and failures
- [x] Add more edge-case fixtures for ordering, recovery, and contention
- [x] Add exportable fixture bundles for cross-language consumption
- [x] Add expected projection snapshots where useful
- [x] Add digest snapshots for new parity cases

Deliverables:
- [x] expanded fixture set
- [x] exportable parity fixture bundle format
- [x] updated golden digests

## Workstream 3 - Reference Documentation

Goal:
- make the current semantic core easy to reason about and port safely

Tasks:
- [x] Document append semantics
- [x] Document projector and replay semantics
- [x] Document precedent and graph query semantics
- [x] Document storage-backend semantic expectations
- [x] Document what counts as an acceptable semantic difference and what does not

Deliverables:
- [x] `docs/reference/APPEND_SEMANTICS.md`
- [x] `docs/reference/PROJECTION_AND_REPLAY_SEMANTICS.md`
- [x] `docs/reference/PRECEDENT_AND_GRAPH_QUERY_SEMANTICS.md`
- [x] `docs/reference/SEMANTIC_PARITY_POLICY.md`

## Workstream 4 - Cross-Language Parity Preparation

Goal:
- make it easy for future Elixir tests to prove equivalence

Tasks:
- [x] Define parity harness inputs and outputs
- [x] Define pass/fail criteria for parity tests
- [x] Identify the Python tests that should be mirrored first in Elixir
- [x] Define the first cross-language replay comparison workflow
- [x] Define how fixture exports will be versioned

Deliverables:
- [x] `docs/reference/PARITY_HARNESS_PLAN.md`
- [x] first-pass mirrored test inventory
- [x] parity pass/fail checklist

## Workstream 5 - Semantic Baseline Release

Goal:
- create a stable checkpoint for the BEAM transition

Tasks:
- [x] Decide whether the checkpoint is a git tag, release branch, or both
- [x] Write semantic baseline release notes
- [x] Record the reference commit or tag in architecture docs
- [x] Define how future semantic changes must be reviewed

Deliverables:
- [x] semantic baseline checkpoint
- [x] semantic baseline notes
- [x] recorded handoff point for BEAM parity work

## Exit Criteria

Phase 1 is complete only when:

- [x] the Python implementation is explicitly treated as the semantic oracle
- [x] invariants are documented instead of implied
- [x] parity assets exist for the first Elixir work to consume
- [x] the first BEAM implementation team can tell exactly what they must preserve
- [x] a stable checkpoint exists for future comparison

## Completion Summary

Phase 1 is complete.

Completed outputs:

- `docs/reference/` semantic reference package
- expanded golden scenarios for failure and action-proposal flows
- checked-in cross-language bundle at `tests/golden/reference_fixture_bundle.json`
- bundle exporter at `scripts/export_reference_fixture_bundle.py`
- fixture-bundle and fixture-parity tests
- semantic baseline checkpoint name `semantic-reference-python-v1`

## Immediate Next Actions After Phase 1

- [ ] begin Phase 2 Elixir umbrella bootstrap
- [ ] add BEAM CI and tooling
- [ ] start implementing runtime and delivery layers without replacing the semantic oracle prematurely
