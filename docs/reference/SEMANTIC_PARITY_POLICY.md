# Semantic Parity Policy

This policy defines what a BEAM implementation must preserve and what may vary internally.

## Authority

Until an explicit handoff decision is recorded, the Python implementation is authoritative for semantics.

## Non-Negotiable Parity Areas

- event type vocabulary
- event envelope field meaning
- payload-hash canonicalization
- payload shape expectations
- idempotency conflict rules
- trace sequencing and first-event rules
- post-`TraceFinished` locking
- projection cursor behavior
- graph, summary, and precedent outputs
- query ordering and staleness safeguards
- digest values for the same fixture inputs

## Acceptable Internal Differences

These may vary as long as observable behavior does not:

- process topology
- supervisor structure
- SQL query formulation
- concurrency model
- batching strategy
- logging and telemetry detail
- exact wall-clock `recorded_at` values

## Narrowly Acceptable Message Differences

Human-readable error text may differ if all of the following remain true:

- the same operation succeeds or fails
- the same error category is preserved
- the same semantic invariant is being enforced

## Change Review Rule

Any change that can affect semantics must update all relevant Phase 1 assets:

- reference docs in `docs/reference`
- affected golden fixtures
- `tests/golden/reference_fixture_bundle.json`
- parity-oriented tests
- semantic baseline notes if the change is intentional

No semantic change is considered complete until those artifacts are updated together.
