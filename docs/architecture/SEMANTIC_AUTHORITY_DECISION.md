# Semantic Authority Decision Criteria

## Decision Being Made

Phase 9 is deciding one thing:

- should the frozen semantic reference remain Python, or
- is the pure semantic core now safe to treat as Elixir-authoritative

This is not a vote on whether the BEAM platform is useful.
That question has already been answered by Phases 4 through 8.

## Default Rule

Until all BEAM authority go-criteria are satisfied, Python remains the authoritative semantic reference.

That default is intentional.
It prevents the project from switching authority because the platform feels more mature or more exciting.

## Scope Of The Decision

The authority decision applies only to frozen semantic behaviors:

- event vocabulary and envelope meaning
- payload validation
- canonical JSON and payload hashing
- append ordering, idempotency, and locking rules
- projection outputs and digests
- query ordering and freshness safeguards
- replay outputs for the same stored event history

The decision does not apply to:

- Phoenix or HTTP transport details
- LiveView operator UX
- workflow notifications and escalation plumbing
- self-hosted packaging and operations
- OTP supervision topology

## BEAM Authority Go-Criteria

The BEAM side is eligible to become authoritative only if all of these are true:

### 1. Scope Freeze

- the exact authority scope is frozen in writing
- BEAM-only product extensions are either excluded from the comparison or mirrored in a new reference contract
- maintainers can say exactly which behaviors are being handed off

### 2. Non-Negotiable Parity Proof

- all non-negotiable parity areas from `docs/reference/SEMANTIC_PARITY_POLICY.md` are covered by automated evidence
- the frozen fixture bundle passes for writes, projections, digests, and replay outcomes
- no unclassified drift remains in ordering, idempotency, trace locking, staleness checks, or digest values

### 3. Query And Replay Classification

- query behavior is compared against the frozen Python reference for trace, graph, and precedent reads
- every diff is classified as fixed, intentionally accepted, or blocking
- any accepted diff is narrow, documented, and does not weaken correctness claims

### 4. Python Consumer Transition Safety

- the project has an explicit story for Python users after authority handoff
- embedded-library and SQLite expectations are either preserved, bridged, or intentionally retired
- versioning and migration notes are written before the authority switch

### 5. Governance And Rollback

- semantic change approval rules are written
- rollback criteria are concrete
- the parity harness has a named long-term owner
- a final ADR records the handoff decision

## No-Go Criteria

The project should deliberately keep Python authoritative if any of the following remain true:

- any non-negotiable parity area lacks automated proof
- accepted diffs would touch ordering, digest stability, idempotency, or staleness safeguards
- the authority scope is muddied by BEAM-only extensions that do not exist in the reference baseline
- the Python local-library or SQLite story is still an active product expectation with no transition plan
- maintainers cannot explain how to roll back a bad authority handoff

## Decision Matrix

### Outcome A: Keep Python As The Permanent Reference

This is the right answer if:

- BEAM remains excellent at runtime but not cleanly better as the semantic oracle
- Python still provides important embedded-library or offline value
- the migration cost would exceed the product benefit

Implication:

- Elixir continues as the production runtime and operator surface
- Python remains the semantic contract source and parity oracle
- future semantic ports remain optional and evidence-driven

### Outcome B: Make Elixir The Semantic Authority

This is the right answer only if:

- parity proof is comprehensive
- downstream compatibility is governed
- rollback is credible
- maintainers gain meaningful simplicity or product leverage from the handoff

Implication:

- Elixir becomes the canonical semantic implementation
- Python becomes an SDK, compatibility layer, or service client
- future semantic changes are reviewed first against the Elixir reference and parity infrastructure

## Product And Operational Motivations

Reasons to keep Python authoritative:

- it already expresses the frozen reference semantics clearly
- it preserves embedded and offline usage
- it keeps the parity oracle independent from the service runtime

Reasons to move authority to Elixir:

- one implementation could reduce long-term semantic duplication
- pure BEAM-native semantics would align the runtime and oracle
- future platform features could evolve with less cross-language coordination

The project should only choose the second path if the simplification is real and measurable, not aspirational.

## Final Phase 9 Decision

Phase 9 closes with this decision on 2026-03-07:

- Python remains the permanent semantic authority for the frozen Phase 1 semantic scope
- BEAM remains the production runtime authority for the self-hosted service, operator console, workflows, and other platform-era extensions
- no further semantic authority handoff work is justified right now

Why this satisfies the criteria:

- the parity report showed no observed frozen-core drift in the current BEAM evidence
- the project still gains meaningful value from an independent Python oracle, embedded mode, CLI, and SQLite or offline reference surface
- a formal authority handoff would add migration and governance cost without clear product benefit for the local-first direction

## Revisit Rule

This decision may be revisited only if all of the following are true:

- the product scope changes enough that the frozen Phase 1 boundary is no longer the right authority scope
- maintainers can show concrete benefit from eliminating Python as the semantic oracle
- a new ADR explicitly replaces the current decision

Absent that, Python remains the semantic reference and the BEAM platform remains the runtime delivery layer.
