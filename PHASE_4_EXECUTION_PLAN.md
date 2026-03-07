# Phase 4 Execution Plan

## Purpose

This file turns Phase 4 from [DECISIONGRAPH_BEAM_MASTERPLAN.md](DECISIONGRAPH_BEAM_MASTERPLAN.md) into an active execution checklist.

Phase 4 is about building the BEAM projection runtime in `dg_projector` so DecisionGraph can catch up, replay, rebuild, and report projection health with the same determinism the Python reference expects.

## Phase Goal

By the end of Phase 4 we should have:

- supervised projection workers owned by OTP
- durable cursor tracking and projection lag reporting
- deterministic incremental catch-up and full replay flows
- BEAM-side trace summary, context graph, and precedent projections
- projection failure handling with retry, backoff, and dead-letter visibility
- parity evidence comparing Elixir projection outputs to Python reference outputs

## Status

Current phase:
- [x] Phase 4 active

Phase complete:
- [x] Phase 4 complete

## Dependencies

Phase 4 depends on these earlier checkpoints:

- [x] Phase 0 direction and scope are frozen
- [x] Phase 1 semantic reference is frozen
- [x] Phase 2 Elixir umbrella foundation is in place
- [x] Phase 3 BEAM event store is in place
- [x] Phase 4 execution is approved and started

## Workstreams

- projector runtime topology
- projection schema and storage
- catch-up, replay, and rebuild flows
- health, failure handling, and admin controls
- parity, resilience, and performance validation

## Workstream 1 - Projector Runtime Topology

Goal:
- make process ownership explicit for long-lived projection work

Tasks:
- [x] define worker identities for tenant-scoped and projection-scoped processing
- [x] define supervisor structure for projector coordinators, workers, and replay jobs
- [x] implement projector registries and worker startup rules
- [x] decide how workers claim projection responsibility without duplicate work
- [x] define worker lifecycle rules for boot, catch-up, idle, replay, and shutdown
- [x] document which state lives in memory versus Postgres

Deliverables:
- [x] projector supervision layout implemented in `beam/apps/dg_projector/`
- [x] worker lifecycle rules documented in `docs/architecture/BEAM_PROJECTION_RUNTIME.md`
- [x] ownership rules documented in `docs/architecture/BEAM_PROJECTION_PROCESS_MODEL.md`

Acceptance Criteria:
- [x] worker ownership is deterministic enough that the same projection is not processed concurrently by competing workers
- [x] projector workers can crash and restart without losing durable cursor position
- [x] runtime ownership boundaries are explicit enough that later API and replay work does not guess where responsibility lives

## Workstream 2 - Projection Schema and Storage

Goal:
- create durable projection state that later APIs and UIs can trust

Tasks:
- [x] design projection tables for trace summary, context graph, precedent index, and projection digests
- [x] design cursor tables and lag metadata for each projection
- [x] decide how projection snapshots and digest checkpoints are stored
- [x] add Ecto migrations for projection tables, indexes, and constraints
- [x] define naming conventions for projection tables and maintenance functions
- [x] define how projection rebuilds reset or replace prior state safely

Deliverables:
- [x] projection migrations under `beam/apps/dg_store/priv/repo/migrations/`
- [x] projection schemas under `beam/apps/dg_projector/lib/decision_graph/projector/`
- [x] schema notes in `docs/architecture/BEAM_PROJECTION_SCHEMA.md`

Acceptance Criteria:
- [x] projection tables can be rebuilt safely without leaving partially valid state behind
- [x] indexes and constraints support deterministic reads for trace summary, graph, and precedent queries
- [x] cursor and digest storage are durable enough to support replay, lag reporting, and parity comparison

## Workstream 3 - Catch-Up, Replay, and Rebuild Flows

Goal:
- make the runtime able to stay current and recover deterministically

Tasks:
- [x] implement incremental catch-up processing from store batches
- [x] implement full replay from event-log origin
- [x] implement projection rebuild flows that can target one or many projections
- [x] define replay locking and coordination so admin jobs do not collide with live workers
- [x] define batch-size, checkpoint, and back-pressure conventions
- [x] implement digest generation during catch-up and replay
- [x] add guardrails for cancelling, resuming, and inspecting replay jobs

Deliverables:
- [x] projection runner modules in `beam/apps/dg_projector/lib/decision_graph/projector/`
- [x] replay coordinator modules in `beam/apps/dg_projector/lib/decision_graph/projector/replay/`
- [x] replay behavior documented in `docs/reference/BEAM_PROJECTION_REPLAY_BEHAVIOR.md`

Acceptance Criteria:
- [x] incremental catch-up can resume from the last durable checkpoint after interruption
- [x] full replay and rebuild produce the same projection outputs as fresh processing from the same event log
- [x] operator controls for replay state are safe enough that live workers and admin jobs do not corrupt each other

## Workstream 4 - Health, Failure Handling, and Admin Controls

Goal:
- make projector operations observable and safe under failure

Tasks:
- [x] implement projection lag, cursor age, and digest status reporting
- [x] implement retry and backoff rules for transient projection failures
- [x] implement dead-letter or failed-job visibility for non-recoverable projection errors
- [x] classify projection failures into stable operator-facing categories
- [x] emit telemetry for worker lag, replay duration, throughput, retry count, and failure reasons
- [x] implement internal admin surfaces for replay start, replay status, and rebuild safety checks
- [x] document operator expectations for degraded and rebuilding projections

Deliverables:
- [x] health/status modules in `beam/apps/dg_projector/`
- [x] telemetry hooks wired into `dg_observability`
- [x] operator guidance in `docs/operations/PROJECTION_RUNTIME.md`

Acceptance Criteria:
- [x] projection lag, cursor age, and failure state are visible without direct database inspection
- [x] transient and non-recoverable projection failures are separated clearly enough for operators to respond correctly
- [x] replay and rebuild controls expose enough status to support debugging and recovery

## Workstream 5 - Parity, Resilience, and Performance Validation

Goal:
- prove the runtime is correct enough to support the service layer

Tasks:
- [x] add parity tests comparing Elixir trace summary outputs to Python reference snapshots
- [x] add parity tests comparing Elixir context graph outputs to Python reference snapshots
- [x] add parity tests comparing Elixir precedent index outputs to Python reference snapshots
- [x] add replay tests covering clean rebuild, interrupted rebuild, and resumed catch-up
- [x] add failure-injection tests for worker crashes and transient datastore errors
- [x] add load tests for large replay and catch-up scenarios
- [x] capture a first projector throughput and lag baseline

Deliverables:
- [x] parity suite under `beam/apps/dg_projector/test/`
- [x] replay resilience coverage under `beam/apps/dg_projector/test/`
- [x] benchmark notes in `docs/benchmarks/PHASE_4_PROJECTOR_BASELINE.md`

Acceptance Criteria:
- [x] parity tests cover trace summary, context graph, and precedent outputs against the frozen Python reference
- [x] resilience tests prove worker crash and recovery behavior instead of assuming supervision is sufficient
- [x] benchmark notes include enough context to compare future replay and catch-up performance meaningfully

## Reference Inputs

Phase 4 must stay aligned with these existing reference assets:

- `docs/reference/PROJECTION_AND_REPLAY_SEMANTICS.md`
- `docs/reference/PRECEDENT_AND_GRAPH_QUERY_SEMANTICS.md`
- `docs/reference/DIGEST_INVARIANTS.md`
- `docs/reference/QUERY_AND_ORDERING_INVARIANTS.md`
- `tests/golden/reference_fixture_bundle.json`

If Elixir projection behavior differs from those assets, the difference must be fixed or explicitly documented as an accepted deviation.

## Validation

Phase 4 should be validated with:

- deterministic parity tests against the Python fixture bundle
- replay and rebuild integration tests against real Postgres state
- failure-injection coverage for worker restarts and transient datastore issues
- projector throughput and lag measurements captured in a baseline report

## Required Evidence

Phase 4 should not be accepted without:

- a checked-in projector parity suite under `beam/apps/dg_projector/test/`
- replay and rebuild run evidence showing durable cursor progression
- operator-facing health or admin status outputs for lag, digest, and failure state
- benchmark notes in `docs/benchmarks/PHASE_4_PROJECTOR_BASELINE.md`

## Exit Criteria

Phase 4 is complete only when:

- [x] the Elixir runtime can run supervised projection workers continuously
- [x] cursor progress and projection lag are durable and inspectable
- [x] full replay and rebuild flows work without corrupting projection state
- [x] trace summary, context graph, and precedent projections exist in Elixir
- [x] retry, backoff, and failure reporting are good enough for operator-facing surfaces
- [x] parity tests show Elixir projection state is trustworthy against the Python reference
- [x] projector load and replay behavior are documented well enough for Phase 5 API work

## Recommended Execution Order

1. projector topology and worker ownership
2. projection tables and migrations
3. incremental catch-up and full replay flows
4. health, telemetry, and failure handling
5. parity, resilience, and performance validation

## Immediate Next Actions

- [x] write the projector process map and supervision sketch
- [x] define the projection table set and migration plan
- [x] implement the first trace summary projection path
- [x] implement cursor progression and lag reporting
- [x] add the first projection parity test using the existing Python fixture bundle

## Notes

Rules for this phase:

- do not expose public network APIs before projection health is believable
- do not collapse pure projection logic into GenServers unnecessarily
- do not relax digest and replay determinism for convenience
- prefer clear operator recovery flows over opaque automation
