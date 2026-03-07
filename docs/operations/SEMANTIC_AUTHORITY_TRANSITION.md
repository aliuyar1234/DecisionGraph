# Semantic Authority Transition

## Purpose

This document defines how DecisionGraph would transition if semantic authority ever moves from Python to Elixir.

It is intentionally operational:

- how the rollout would happen
- what release rules apply
- what Python users should expect
- when the project must stop and roll back

This document does not itself declare that the handoff should happen.

## Current State

Current position on 2026-03-07:

- Python remains authoritative for the frozen Phase 1 semantic scope
- BEAM shows strong parity evidence for frozen write, projection, query, and replay behavior
- Phase 9 closes without an authority handoff because the local-first product still benefits from keeping Python as the oracle

## Transition Principles

Any authority switch must obey these rules:

- explicit over implicit
- reversible over clever
- major-release only for authority changes
- no silent auto-routing from Python local APIs to BEAM HTTP
- preserve self-hosted and GitHub-download usability during the transition

## Supported Consumer Modes

### Mode 1: Python local/reference mode

Use when:

- running frozen reference tests
- replaying fixtures locally
- using SQLite or embedded local Postgres directly
- doing offline or single-process workflows

### Mode 2: Python-to-BEAM service mode

Use when:

- interacting with the shared self-hosted BEAM runtime
- using authenticated writes and projection-backed reads through HTTP
- relying on replay admin controls, workflow operations, and operator-centric runtime behavior

This mode should be reached through an explicit Python service client, not through hidden transport switching.

### Mode 3: Native BEAM operator mode

Use when:

- operating the web console directly
- calling the BEAM HTTP surface from non-Python systems
- managing self-hosted runtime health and replay jobs

## Transition Stages

### Stage A: Current state

- Python authoritative
- BEAM runtime operational
- no authority change

### Stage B: Bridge introduction

Required before any handoff:

- explicit Python service client design finalized
- migration guide written
- compatibility rules published
- no existing Python local API defaults changed

### Stage C: Dual-support period

Required before any handoff declaration:

- local Python mode still works
- explicit Python service mode is documented and tested
- fixture bundle and parity suites remain release gates
- real-user migration feedback is collected where possible

### Stage D: Authority handoff candidate

Only consider this stage if:

- Phase 9 parity report remains green for frozen-core semantics
- transition policy is published
- rollback criteria are published
- maintainers are prepared to support the new authoritative path

### Stage E: Post-decision stabilization

If Elixir becomes authoritative:

- Python remains supported as a compatibility/client surface according to the declared release policy
- removals or default changes happen only through announced deprecation windows
- post-handoff semantic changes must continue to update reference docs, fixture bundle, and parity coverage

If Python remains authoritative:

- BEAM continues as the production runtime and platform delivery layer
- future semantic ports remain optional and evidence-driven

## Versioning Rules

Authority switch policy:

- semantic authority handoff requires a major release
- default execution-mode changes require a major release
- additive explicit client surfaces may ship in a minor release
- deprecations require at least one full minor cycle before removal

Examples:

- adding `DecisionGraphServiceClient` is minor-safe
- making `DecisionGraph(...)` remote by default is major-only
- removing embedded local constructors is major-only

## Release Gates For A Handoff Candidate

Before declaring Elixir authoritative, all of these must be true:

- Phase 9 parity report is current and green for the frozen scope
- Python compatibility and migration docs are published
- a Python service-client story exists or the local-only story is deliberately retained
- rollback and governance docs are approved
- release notes call out the authority decision explicitly

## Rollback Triggers

Rollback must be required if any of the following appear after a handoff:

- digest or ordering regressions in frozen-core behavior
- idempotency, trace-sequence, or stale-read regressions
- Python consumer breakage beyond the declared migration envelope
- self-hosted user confusion caused by ambiguous local-versus-service execution behavior
- inability to explain or reverse the new authority path within one release cycle

## Rollback Actions

If rollback is triggered:

1. stop declaring Elixir authoritative in release messaging
2. restore Python as the explicit semantic oracle in docs and ADRs
3. keep the explicit Python service client if useful, but treat it as a transport client rather than the new oracle
4. re-open the parity diff register and document the regression
5. require a new ADR before attempting another handoff

## Post-Handoff Semantic Review Rules

If Elixir ever becomes authoritative, future semantic changes must still follow strict review discipline.

Minimum rule set:

- update the relevant reference docs in `docs/reference/`
- update the frozen fixture bundle when semantic outputs change
- update parity tests on both sides where applicable
- classify any intentional diff before release
- record authority-relevant changes in migration notes and release notes

This section is intentionally lighter than the full governance model.
The dedicated governance document in Workstream 5 should turn these rules into named ownership and approval policy.

## Standing Operational Guidance

For the current repo state:

- do not announce an authority handoff
- use the Phase 9 parity report as the frozen-core correctness baseline
- treat this document as a contingency runbook only if a future ADR reopens the authority question
