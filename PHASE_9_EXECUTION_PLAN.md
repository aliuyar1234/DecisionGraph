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
- [ ] Phase 9 active

Phase complete:
- [ ] Phase 9 complete

## Dependencies

Phase 9 depends on these earlier checkpoints:

- [x] Phase 0 direction and scope are frozen
- [x] Phase 1 semantic reference is frozen
- [x] Phase 2 Elixir umbrella foundation is in place
- [x] Phase 3 BEAM event store is in place
- [ ] Phases 4 through 8 are complete enough to judge real platform behavior
- [ ] full parity harness inputs and operational evidence are available
- [ ] Phase 9 execution is approved and started

## Workstreams

- authority decision and scope inventory
- semantic port implementation
- parity proof and acceptance criteria
- authority handoff and SDK bridge strategy
- rollback, governance, and long-term ownership

## Workstream 1 - Authority Decision and Scope Inventory

Goal:
- decide what would actually need to move before touching core semantics

Tasks:
- [ ] inventory the remaining Python-owned semantic behaviors
- [ ] separate pure logic from transport, storage, and operational concerns
- [ ] identify which semantic areas already have strong Elixir parity evidence
- [ ] define the decision criteria for a full semantic authority handoff
- [ ] define the decision criteria for deliberately keeping Python as the permanent reference
- [ ] capture the product and operational motivations for either path

Deliverables:
- [ ] semantic authority inventory in `docs/architecture/SEMANTIC_AUTHORITY_INVENTORY.md`
- [ ] go/no-go criteria in `docs/architecture/SEMANTIC_AUTHORITY_DECISION.md`
- [ ] explicit recommendation memo for leadership or maintainers

Acceptance Criteria:
- [ ] the project has a complete inventory of what Python still owns semantically before any authority change is attempted
- [ ] go and no-go criteria are written before deeper semantic port work begins
- [ ] the decision frame includes technical, operational, and downstream compatibility implications rather than only implementation preference

## Workstream 2 - Semantic Port Implementation

Goal:
- port only what is necessary, and only behind strong reference evidence

Tasks:
- [ ] port any remaining pure validation logic needed for Elixir authority
- [ ] port any remaining envelope normalization and canonicalization logic
- [ ] port any remaining deterministic digest logic not yet owned by Elixir
- [ ] port any remaining query or projection semantics needed for authority completeness
- [ ] keep the ports pure and testable outside long-lived processes
- [ ] document any intentionally retained Python compatibility layers

Deliverables:
- [ ] Elixir semantic modules under `beam/apps/dg_domain/`
- [ ] updated semantic contracts in `docs/reference/`
- [ ] change log of semantic ownership moved from Python to Elixir

Acceptance Criteria:
- [ ] any semantic logic moved into Elixir remains pure and testable outside long-lived runtime processes
- [ ] no semantic area is ported without a reference contract or fixture proving what must be preserved
- [ ] retained Python compatibility layers are documented clearly enough that ownership is not ambiguous

## Workstream 3 - Parity Proof and Acceptance Criteria

Goal:
- make authority change a proof exercise rather than a confidence exercise

Tasks:
- [ ] run the full parity harness against all frozen fixtures and digests
- [ ] compare Python and Elixir outputs for writes, projections, queries, and replays
- [ ] classify every diff as fixed, intentionally accepted, or blocking
- [ ] define the exact threshold for declaring Elixir authoritative
- [ ] capture performance and operability tradeoffs observed during parity work
- [ ] refuse handoff if parity evidence is weak or mixed

Deliverables:
- [ ] parity evidence report in `docs/benchmarks/PHASE_9_PARITY_REPORT.md`
- [ ] accepted-diff register if any deltas are intentionally retained
- [ ] authority-handoff recommendation grounded in measured results

Acceptance Criteria:
- [ ] every meaningful Python-versus-Elixir diff is classified as fixed, intentionally accepted, or blocking
- [ ] the threshold for declaring Elixir authoritative is explicit and met with evidence rather than intuition
- [ ] parity reporting includes both correctness and operational tradeoffs that matter to maintainers and users

## Workstream 4 - Authority Handoff and SDK Bridge Strategy

Goal:
- make the user-facing transition safe if semantic authority changes

Tasks:
- [ ] define how the Python package behaves if Elixir becomes authoritative
- [ ] define SDK bridge or service-client strategy for Python consumers
- [ ] define versioning and migration notes for downstream users
- [ ] define testing and release rules for a dual-language transition period
- [ ] decide what remains embedded-library friendly versus service-only
- [ ] document how future semantic changes must be reviewed post-handoff

Deliverables:
- [ ] SDK bridge plan in `docs/architecture/PYTHON_SDK_BRIDGE_PLAN.md`
- [ ] transition policy in `docs/operations/SEMANTIC_AUTHORITY_TRANSITION.md`
- [ ] updated compatibility guidance in `docs/reference/PYTHON_SDK_SERVICE_COMPATIBILITY.md`

Acceptance Criteria:
- [ ] Python consumers have a clear path whether Elixir becomes authoritative or Python remains the reference
- [ ] compatibility, versioning, and migration notes are explicit enough to avoid surprise breakage downstream
- [ ] the handoff plan preserves enough reversibility to back out of a bad authority transition

## Workstream 5 - Rollback, Governance, and Long-Term Ownership

Goal:
- ensure the decision is reversible enough to make responsibly

Tasks:
- [ ] define rollback criteria if an authority handoff causes unacceptable regressions
- [ ] define governance for semantic changes after the decision
- [ ] define who owns parity harness upkeep long term
- [ ] decide whether Gleam should be reconsidered for small pure libraries after stabilization
- [ ] document the permanent reference story if Python remains authoritative
- [ ] record the final decision in an ADR or equivalent architecture record

Deliverables:
- [ ] rollback and governance rules in `docs/architecture/SEMANTIC_GOVERNANCE.md`
- [ ] final ADR documenting the authority decision
- [ ] long-term maintenance notes for parity infrastructure

Acceptance Criteria:
- [ ] rollback criteria are concrete enough that maintainers know when to reverse an authority handoff
- [ ] long-term governance makes it clear who approves semantic changes and who maintains parity infrastructure
- [ ] the final decision is recorded in a durable architecture artifact, even if the answer is to keep Python authoritative

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

- [ ] the project has a documented yes-or-no decision on semantic authority migration
- [ ] any Elixir semantic port work has strong parity evidence behind it
- [ ] downstream compatibility implications are documented
- [ ] rollback and governance rules are explicit
- [ ] the team can explain why Python remains authoritative or why Elixir now does

## Recommended Execution Order

1. authority decision criteria and scope inventory
2. semantic port work only where needed
3. full parity proof and diff classification
4. authority handoff and SDK bridge planning
5. rollback, governance, and final decision capture

## Immediate Next Actions

- [ ] inventory the remaining Python-owned semantic logic
- [ ] write the go/no-go criteria before porting any new semantics
- [ ] run a gap analysis between current Elixir behavior and the frozen reference docs
- [ ] define the downstream Python compatibility story for each possible outcome
- [ ] prepare the parity evidence report template before the full comparison run

## Notes

Rules for this phase:

- do not switch semantic authority because the Elixir platform feels more exciting
- do not accept vague "close enough" parity for core semantics
- preserve reversibility until the authority decision is demonstrably safe
- treat "Python remains the oracle" as a valid successful outcome if evidence points there
