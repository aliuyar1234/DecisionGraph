# Semantic Ownership Changelog

## Purpose

This changelog records the semantic ownership split that emerged during the BEAM platform build.

It does not imply that semantic authority moved to Elixir.
Phase 9 closed with Python still authoritative for the frozen Phase 1 scope.

## Ownership Timeline

### Phase 1

- Python was frozen as the semantic reference
- the fixture bundle and reference docs became the migration oracle

### Phases 3 through 5

- BEAM implemented the operational write path, projector runtime, and service query surfaces
- parity tests were added so BEAM runtime behavior could be compared against the Python oracle

### Phase 9

- the repo confirmed strong frozen-core BEAM parity
- the project chose to keep Python as the permanent semantic authority
- the ownership split became a stable architecture rather than a temporary migration phase

## Current Ownership By Area

| Area | Semantic authority | BEAM status | Notes |
| --- | --- | --- | --- |
| Event envelope and frozen event vocabulary | Python | mirrored | BEAM mirrors the frozen vocabulary; `WorkflowReviewRequested` remains a BEAM-only extension outside the frozen baseline |
| Payload validation and PII guard | Python | mirrored | BEAM uses pure validation modules for runtime parity, but Python remains the oracle for frozen-core rules |
| Canonical JSON and payload hashing | Python | mirrored | BEAM has pure equivalents used in store and projector flows; authority stays Python-led |
| Append ordering, idempotency, and trace locking | Python | operational owner | BEAM is the self-hosted write runtime, but the frozen contract still comes from the Python reference docs and fixtures |
| Projection outputs and deterministic digests | Python | operational owner | BEAM computes the operational projections and digests; parity remains release-gated against Python fixtures |
| Query ordering and freshness safeguards | Python | operational owner | BEAM serves trace, graph, precedent, and health reads through the runtime, while Python remains the reference contract source |
| Embedded library, CLI, and SQLite mode | Python | not replaced | This remains intentionally Python-owned product value |
| Workflow review and operator-era extensions | BEAM | BEAM-owned | These are outside the frozen Phase 1 semantic authority scope |

## Phase 9 Outcome

The important Phase 9 outcome is:

- no semantic authority transfer occurred
- no speculative additional semantic port was required
- mirrored BEAM semantic primitives remain in place because they are useful for the runtime
- the Python local and reference surface remains an intentional long-term part of the product

## Update Rule

Update this changelog whenever one of the following happens:

- a frozen-core semantic area changes authority
- a new semantic mirror is added on the BEAM side
- a BEAM-only extension is formally added to the frozen comparison scope
- a future ADR changes the current long-term split
