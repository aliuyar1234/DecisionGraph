# Parity Harness Plan

This is the first-pass plan for proving Python and Elixir equivalence.

## Primary Input

The canonical cross-language input is:

- `tests/golden/reference_fixture_bundle.json`

Format:

- `format = decisiongraph.reference_fixture_bundle`
- `version = 1`

Each scenario includes:

- metadata
- ordered event envelopes
- expected component digests
- event count
- event-type sequence
- normalized projection snapshots

## First Comparison Workflow

For each scenario:

1. load ordered events from the bundle
2. append them to the candidate implementation
3. rebuild projections from the stored events
4. compare projection cursor
5. compare normalized projection snapshots
6. compare component digests
7. compare full projection digest

## Pass Criteria

A scenario passes only if:

- every event is accepted or rejected in the same place for the same reason category
- the stored event ordering matches
- the normalized projection snapshot matches
- component digests match
- the full projection digest matches

## Fail Criteria

The harness fails if any of the following drift:

- event acceptance or rejection behavior
- idempotency reuse behavior
- trace sequencing behavior
- final graph / summary / precedent state
- query ordering assumptions needed to produce the snapshot
- digest outputs

## Mirrored Test Inventory

These Python tests should be mirrored first on the Elixir side:

- `tests/unit/test_validation_boundary.py`
- `tests/unit/test_canonical_json.py`
- `tests/unit/test_inmemory_store.py`
- `tests/integration/test_sqlite_backend.py`
- `tests/integration/test_projection_replay.py`
- `tests/unit/test_digests.py`
- `tests/e2e/test_fixtures.py`
- `tests/e2e/test_ordering_contracts.py`
- `tests/integration/test_parity.py`

## Bundle Versioning

- bump the bundle `version` only when the bundle format changes
- do not bump the bundle version for ordinary fixture additions
- fixture additions still require digest and snapshot regeneration

## Operator Checklist

- fixture bundle regenerated
- new bundle reviewed in diff form
- parity tests green on Python
- Elixir candidate compared against the same bundle
- any intended semantic delta documented before acceptance
