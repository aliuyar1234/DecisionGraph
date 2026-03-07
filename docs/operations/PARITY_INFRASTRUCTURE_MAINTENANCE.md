# Parity Infrastructure Maintenance

## Purpose

This runbook defines the long-term upkeep rules for DecisionGraph's parity infrastructure after Phase 9.

The goal is simple:

- keep the Python reference and BEAM runtime aligned for the frozen Phase 1 scope
- detect semantic drift early
- prevent "close enough" releases

## Canonical Parity Assets

The minimum parity asset set is:

- `docs/reference/`
- `tests/golden/reference_fixture_bundle.json`
- Python semantic tests for frozen-core behavior
- `beam/apps/dg_store/test/decision_graph/store/parity_test.exs`
- `beam/apps/dg_projector/test/decision_graph/projector/parity_test.exs`
- `beam/apps/dg_projector/test/decision_graph/projector/query_parity_test.exs`
- replay and rebuild integration coverage under `beam/apps/dg_projector/test/decision_graph/projector/integration_test.exs`
- `docs/benchmarks/PHASE_9_PARITY_REPORT.md`

These assets are a release gate, not optional documentation.

## Owner Responsibilities

Reference-core owner:

- keeps frozen-core Python behavior and fixture outputs authoritative

BEAM parity owner:

- keeps the BEAM parity suites current and interprets failures

Release owner:

- ensures parity evidence is current before shipping changes that can affect semantics

## Required Update Flow

Whenever a frozen-core semantic change is intentional, maintainers must do all of the following:

1. update the Python reference behavior and tests
2. update the relevant docs in `docs/reference/`
3. update `tests/golden/reference_fixture_bundle.json`
4. update the affected BEAM parity suites
5. update `docs/benchmarks/PHASE_9_PARITY_REPORT.md` if the diff register or authority interpretation changes
6. update `docs/reference/SEMANTIC_OWNERSHIP_CHANGELOG.md` if ownership boundaries change

Skipping any of these steps means the semantic change is incomplete.

## Required Validation

At minimum, frozen-core semantic changes should rerun the targeted suites for the impacted area.

The standard Phase 9 proof set is:

- `mix test apps/dg_store/test/decision_graph/store/parity_test.exs`
- `mix test apps/dg_projector/test/decision_graph/projector/parity_test.exs`
- `mix test apps/dg_projector/test/decision_graph/projector/query_parity_test.exs`
- `mix test apps/dg_projector/test/decision_graph/projector/integration_test.exs`

If a change touches only docs or governance artifacts, rerunning the full proof set is not required, but the docs must still stay consistent with the latest accepted evidence.

## Failure Triage

When parity fails, classify the problem before fixing it:

- reference drift: the Python oracle or docs changed intentionally but the BEAM side was not updated yet
- implementation drift: the BEAM side changed in a way that no longer matches the frozen reference
- scope contamination: a BEAM-only extension leaked into frozen-core comparison logic
- harness defect: the fixtures, test harness, or comparison logic is wrong

Do not mark a failure resolved until the classification is written down somewhere visible in the affected change.

## Acceptance Standard

The frozen-core standard remains:

- no unclassified drift in ordering
- no unclassified drift in idempotency or trace locking
- no unclassified drift in stale-read safeguards
- no unclassified drift in digest values for the same fixtures

Human-readable error text may vary only if the semantic category and invariant are preserved.

## When To Reopen Phase 9

Phase 9 does not reopen for normal parity maintenance.

Reopen the authority question only if:

- maintainers propose changing semantic authority
- the frozen Phase 1 scope is intentionally widened
- the Python local and reference surface is being retired or materially changed

That reopen requires a new ADR, not just a failing test.
