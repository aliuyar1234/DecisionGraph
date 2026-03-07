# Phase 9 Execution Plan

## Purpose

This file turns Phase 9 from [DECISIONGRAPH_BEAM_MASTERPLAN.md](DECISIONGRAPH_BEAM_MASTERPLAN.md) into an active execution checklist.

Phase 9 is the evidence-based decision point for whether DecisionGraph should keep Python as the permanent semantic reference or move semantic authority fully into Elixir.

## Phase Goal

By the end of Phase 9 we should have:

- a clear go or no-go decision on BEAM-native semantic authority
- a documented inventory of remaining Python-owned semantic logic
- parity evidence for any Elixir semantic port work
- a safe authority-handoff plan if the Elixir core becomes authoritative
- a deliberate fallback decision if Python remains the long-term oracle

## Status

Current phase:
- [x] Phase 9 active

Phase complete:
- [x] Phase 9 complete

Phase readiness:
- [x] Phase 9 prerequisites are satisfied through Phase 8

## Dependencies

Phase 9 depends on these earlier checkpoints:

- [x] Phase 0 direction and scope are frozen
- [x] Phase 1 semantic reference is frozen
- [x] Phase 2 Elixir umbrella foundation is in place
- [x] Phase 3 BEAM event store is in place
- [x] Phases 4 through 8 are complete enough to judge real platform behavior
- [x] full parity harness inputs and operational evidence are available
- [x] Phase 9 execution is approved and started

## Workstreams

- authority decision and scope inventory
- semantic port scope resolution
- parity proof and acceptance criteria
- authority handoff and SDK bridge strategy
- rollback, governance, and long-term ownership

## Workstream 1 - Authority Decision and Scope Inventory

Goal:
- decide what would actually need to move before touching core semantics

Tasks:
- [x] inventory the remaining Python-owned semantic behaviors
- [x] separate pure logic from transport, storage, and operational concerns
- [x] identify which semantic areas already have strong Elixir parity evidence
- [x] define the decision criteria for a full semantic authority handoff
- [x] define the decision criteria for deliberately keeping Python as the permanent reference
- [x] capture the product and operational motivations for either path

Deliverables:
- [x] semantic authority inventory in `docs/architecture/SEMANTIC_AUTHORITY_INVENTORY.md`
- [x] go/no-go criteria in `docs/architecture/SEMANTIC_AUTHORITY_DECISION.md`
- [x] explicit recommendation memo for leadership or maintainers in `docs/architecture/SEMANTIC_AUTHORITY_RECOMMENDATION.md`

Acceptance Criteria:
- [x] the project has a complete inventory of what Python still owns semantically before any authority change is attempted
- [x] go and no-go criteria are written before deeper semantic port work begins
- [x] the decision frame includes technical, operational, and downstream compatibility implications rather than only implementation preference

## Workstream 2 - Semantic Port Scope Resolution

Goal:
- confirm what BEAM already owns semantically, and avoid speculative ports that do not improve the final authority decision

Tasks:
- [x] confirm which frozen validation rules already have BEAM-native pure implementations
- [x] confirm which envelope normalization, canonicalization, and digest rules are already mirrored in BEAM
- [x] confirm which query and projection semantics are already mirrored in BEAM for the operational runtime
- [x] avoid speculative ports that do not change the authority decision
- [x] keep the retained BEAM semantic modules pure and testable outside long-lived processes
- [x] document intentionally retained Python-owned compatibility layers and ownership boundaries

Deliverables:
- [x] existing Elixir semantic modules inventoried under `beam/apps/dg_domain/`
- [x] updated semantic contracts and ownership notes in `docs/reference/`
- [x] semantic ownership changelog in `docs/reference/SEMANTIC_OWNERSHIP_CHANGELOG.md`

Acceptance Criteria:
- [x] retained BEAM semantic logic remains pure and testable outside long-lived runtime processes
- [x] no additional semantic area is ported without a reference contract or fixture proving what must be preserved
- [x] retained Python compatibility layers are documented clearly enough that ownership is not ambiguous

## Workstream 3 - Parity Proof and Acceptance Criteria

Goal:
- make authority change a proof exercise rather than a confidence exercise

Tasks:
- [x] run the full parity harness against all frozen fixtures and digests
- [x] compare Python and Elixir outputs for writes, projections, queries, and replays
- [x] classify every diff as fixed, intentionally accepted, or blocking
- [x] define the exact threshold for declaring Elixir authoritative
- [x] capture performance and operability tradeoffs observed during parity work
- [x] refuse handoff if parity evidence is weak or mixed

Deliverables:
- [x] parity evidence report in `docs/benchmarks/PHASE_9_PARITY_REPORT.md`
- [x] diff register captured in `docs/benchmarks/PHASE_9_PARITY_REPORT.md` with no intentionally accepted frozen-core deltas at this time
- [x] authority-handoff recommendation grounded in measured results

Acceptance Criteria:
- [x] every meaningful Python-versus-Elixir diff is classified as fixed, intentionally accepted, or blocking
- [x] the threshold for declaring Elixir authoritative is explicit and met with evidence rather than intuition
- [x] parity reporting includes both correctness and operational tradeoffs that matter to maintainers and users

## Workstream 4 - Authority Handoff and SDK Bridge Strategy

Goal:
- make the user-facing transition safe if semantic authority changes

Tasks:
- [x] define how the Python package behaves if Elixir becomes authoritative
- [x] define SDK bridge or service-client strategy for Python consumers
- [x] define versioning and migration notes for downstream users
- [x] define testing and release rules for a dual-language transition period
- [x] decide what remains embedded-library friendly versus service-only
- [x] document how future semantic changes must be reviewed post-handoff

Deliverables:
- [x] SDK bridge plan in `docs/architecture/PYTHON_SDK_BRIDGE_PLAN.md`
- [x] transition policy in `docs/operations/SEMANTIC_AUTHORITY_TRANSITION.md`
- [x] updated compatibility guidance in `docs/reference/PYTHON_SDK_SERVICE_COMPATIBILITY.md`

Acceptance Criteria:
- [x] Python consumers have a clear path whether Elixir becomes authoritative or Python remains the reference
- [x] compatibility, versioning, and migration notes are explicit enough to avoid surprise breakage downstream
- [x] the handoff plan preserves enough reversibility to back out of a bad authority transition

## Workstream 5 - Rollback, Governance, and Long-Term Ownership

Goal:
- ensure the decision is reversible enough to make responsibly

Tasks:
- [x] define rollback criteria if an authority handoff causes unacceptable regressions
- [x] define governance for semantic changes after the decision
- [x] define who owns parity harness upkeep long term
- [x] decide whether Gleam should be reconsidered for small pure libraries after stabilization
- [x] document the permanent reference story if Python remains authoritative
- [x] record the final decision in an ADR or equivalent architecture record

Deliverables:
- [x] rollback and governance rules in `docs/architecture/SEMANTIC_GOVERNANCE.md`
- [x] final ADR documenting the authority decision in `docs/architecture/ADR_PHASE_9_SEMANTIC_AUTHORITY.md`
- [x] long-term maintenance notes for parity infrastructure in `docs/operations/PARITY_INFRASTRUCTURE_MAINTENANCE.md`

Acceptance Criteria:
- [x] rollback criteria are concrete enough that maintainers know when to reverse an authority handoff
- [x] long-term governance makes it clear who approves semantic changes and who maintains parity infrastructure
- [x] the final decision is recorded in a durable architecture artifact, even if the answer is to keep Python authoritative

## Reference Inputs

Phase 9 must stay aligned with these earlier assets:

- `docs/reference/SEMANTIC_PARITY_POLICY.md`
- `docs/reference/PARITY_HARNESS_PLAN.md`
- `tests/golden/reference_fixture_bundle.json`
- `docs/architecture/ADR_PYTHON_REFERENCE_CORE.md`

This phase is successful only if the final decision is evidence-based, even if the answer is to keep Python as the permanent reference.

## Validation

Phase 9 should be validated with:

- full parity-harness runs against frozen fixtures and digests
- diff classification reviews for writes, projections, queries, and replays
- downstream compatibility review for Python users and service consumers
- governance and rollback review before any authority handoff is declared

## Required Evidence

Phase 9 should not be accepted without:

- a completed semantic authority inventory and go/no-go criteria
- a parity evidence report in `docs/benchmarks/PHASE_9_PARITY_REPORT.md`
- documented compatibility and transition policy for Python users
- a final ADR recording the authority decision and governance model

## Exit Criteria

Phase 9 is complete only when:

- [x] the project has a documented yes-or-no decision on semantic authority migration
- [x] any retained Elixir semantic port work has strong parity evidence behind it
- [x] downstream compatibility implications are documented
- [x] rollback and governance rules are explicit
- [x] the team can explain why Python remains authoritative or why Elixir now does

## Recommended Execution Order

1. authority decision criteria and scope inventory
2. semantic port work only where needed
3. full parity proof and diff classification
4. authority handoff and SDK bridge planning
5. rollback, governance, and final decision capture

## Immediate Next Actions

- [x] inventory the remaining Python-owned semantic logic
- [x] write the go/no-go criteria before porting any new semantics
- [x] run a gap analysis between current Elixir behavior and the frozen reference docs
- [x] define the downstream Python compatibility story for each possible outcome
- [x] prepare the parity evidence report template before the full comparison run

## Notes

Rules for this phase:

- do not switch semantic authority because the Elixir platform feels more exciting
- do not accept vague "close enough" parity for core semantics
- preserve reversibility until the authority decision is demonstrably safe
- treat "Python remains the oracle" as a valid successful outcome if evidence points there

## Final Decision

Phase 9 closes with this decision:

- Python remains the permanent semantic reference for the frozen Phase 1 scope
- BEAM remains the authoritative runtime and product delivery layer for the self-hosted platform
- no additional speculative semantic rewrite is required for Phase 9 completion
- any future revisit of BEAM semantic authority requires a new ADR and materially different product constraints
