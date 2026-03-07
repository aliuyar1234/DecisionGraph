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
- [ ] Phase 4 active

Phase complete:
- [ ] Phase 4 complete

## Dependencies

Phase 4 depends on these earlier checkpoints:

- [x] Phase 0 direction and scope are frozen
- [x] Phase 1 semantic reference is frozen
- [x] Phase 2 Elixir umbrella foundation is in place
- [x] Phase 3 BEAM event store is in place
- [ ] Phase 4 execution is approved and started

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
- [ ] define worker identities for tenant-scoped and projection-scoped processing
- [ ] define supervisor structure for projector coordinators, workers, and replay jobs
- [ ] implement projector registries and worker startup rules
- [ ] decide how workers claim projection responsibility without duplicate work
- [ ] define worker lifecycle rules for boot, catch-up, idle, replay, and shutdown
- [ ] document which state lives in memory versus Postgres

Deliverables:
- [ ] projector supervision layout implemented in `beam/apps/dg_projector/`
- [ ] worker lifecycle rules documented in `docs/architecture/BEAM_PROJECTION_RUNTIME.md`
- [ ] ownership rules documented in `docs/architecture/BEAM_PROJECTION_PROCESS_MODEL.md`

Acceptance Criteria:
- [ ] worker ownership is deterministic enough that the same projection is not processed concurrently by competing workers
- [ ] projector workers can crash and restart without losing durable cursor position
- [ ] runtime ownership boundaries are explicit enough that later API and replay work does not guess where responsibility lives

## Workstream 2 - Projection Schema and Storage

Goal:
- create durable projection state that later APIs and UIs can trust

Tasks:
- [ ] design projection tables for trace summary, context graph, precedent index, and projection digests
- [ ] design cursor tables and lag metadata for each projection
- [ ] decide how projection snapshots and digest checkpoints are stored
- [ ] add Ecto migrations for projection tables, indexes, and constraints
- [ ] define naming conventions for projection tables and maintenance functions
- [ ] define how projection rebuilds reset or replace prior state safely

Deliverables:
- [ ] projection migrations under `beam/apps/dg_projector/priv/repo/migrations/`
- [ ] projection schemas under `beam/apps/dg_projector/lib/decision_graph/projector/`
- [ ] schema notes in `docs/architecture/BEAM_PROJECTION_SCHEMA.md`

Acceptance Criteria:
- [ ] projection tables can be rebuilt safely without leaving partially valid state behind
- [ ] indexes and constraints support deterministic reads for trace summary, graph, and precedent queries
- [ ] cursor and digest storage are durable enough to support replay, lag reporting, and parity comparison

## Workstream 3 - Catch-Up, Replay, and Rebuild Flows

Goal:
- make the runtime able to stay current and recover deterministically

Tasks:
- [ ] implement incremental catch-up processing from store batches
- [ ] implement full replay from event-log origin
- [ ] implement projection rebuild flows that can target one or many projections
- [ ] define replay locking and coordination so admin jobs do not collide with live workers
- [ ] define batch-size, checkpoint, and back-pressure conventions
- [ ] implement digest generation during catch-up and replay
- [ ] add guardrails for cancelling, resuming, and inspecting replay jobs

Deliverables:
- [ ] projection runner modules in `beam/apps/dg_projector/lib/decision_graph/projector/`
- [ ] replay coordinator modules in `beam/apps/dg_projector/lib/decision_graph/projector/replay/`
- [ ] replay behavior documented in `docs/reference/BEAM_PROJECTION_REPLAY_BEHAVIOR.md`

Acceptance Criteria:
- [ ] incremental catch-up can resume from the last durable checkpoint after interruption
- [ ] full replay and rebuild produce the same projection outputs as fresh processing from the same event log
- [ ] operator controls for replay state are safe enough that live workers and admin jobs do not corrupt each other

## Workstream 4 - Health, Failure Handling, and Admin Controls

Goal:
- make projector operations observable and safe under failure

Tasks:
- [ ] implement projection lag, cursor age, and digest status reporting
- [ ] implement retry and backoff rules for transient projection failures
- [ ] implement dead-letter or failed-job visibility for non-recoverable projection errors
- [ ] classify projection failures into stable operator-facing categories
- [ ] emit telemetry for worker lag, replay duration, throughput, retry count, and failure reasons
- [ ] implement internal admin surfaces for replay start, replay status, and rebuild safety checks
- [ ] document operator expectations for degraded and rebuilding projections

Deliverables:
- [ ] health/status modules in `beam/apps/dg_projector/`
- [ ] telemetry hooks wired into `dg_observability`
- [ ] operator guidance in `docs/operations/PROJECTION_RUNTIME.md`

Acceptance Criteria:
- [ ] projection lag, cursor age, and failure state are visible without direct database inspection
- [ ] transient and non-recoverable projection failures are separated clearly enough for operators to respond correctly
- [ ] replay and rebuild controls expose enough status to support debugging and recovery

## Workstream 5 - Parity, Resilience, and Performance Validation

Goal:
- prove the runtime is correct enough to support the service layer

Tasks:
- [ ] add parity tests comparing Elixir trace summary outputs to Python reference snapshots
- [ ] add parity tests comparing Elixir context graph outputs to Python reference snapshots
- [ ] add parity tests comparing Elixir precedent index outputs to Python reference snapshots
- [ ] add replay tests covering clean rebuild, interrupted rebuild, and resumed catch-up
- [ ] add failure-injection tests for worker crashes and transient datastore errors
- [ ] add load tests for large replay and catch-up scenarios
- [ ] capture a first projector throughput and lag baseline

Deliverables:
- [ ] parity suite under `beam/apps/dg_projector/test/`
- [ ] replay resilience coverage under `beam/apps/dg_projector/test/`
- [ ] benchmark notes in `docs/benchmarks/PHASE_4_PROJECTOR_BASELINE.md`

Acceptance Criteria:
- [ ] parity tests cover trace summary, context graph, and precedent outputs against the frozen Python reference
- [ ] resilience tests prove worker crash and recovery behavior instead of assuming supervision is sufficient
- [ ] benchmark notes include enough context to compare future replay and catch-up performance meaningfully

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

- [ ] the Elixir runtime can run supervised projection workers continuously
- [ ] cursor progress and projection lag are durable and inspectable
- [ ] full replay and rebuild flows work without corrupting projection state
- [ ] trace summary, context graph, and precedent projections exist in Elixir
- [ ] retry, backoff, and failure reporting are good enough for operator-facing surfaces
- [ ] parity tests show Elixir projection state is trustworthy against the Python reference
- [ ] projector load and replay behavior are documented well enough for Phase 5 API work

## Recommended Execution Order

1. projector topology and worker ownership
2. projection tables and migrations
3. incremental catch-up and full replay flows
4. health, telemetry, and failure handling
5. parity, resilience, and performance validation

## Immediate Next Actions

- [ ] write the projector process map and supervision sketch
- [ ] define the projection table set and migration plan
- [ ] implement the first trace summary projection path
- [ ] implement cursor progression and lag reporting
- [ ] add the first projection parity test using the existing Python fixture bundle

## Notes

Rules for this phase:

- do not expose public network APIs before projection health is believable
- do not collapse pure projection logic into GenServers unnecessarily
- do not relax digest and replay determinism for convenience
- prefer clear operator recovery flows over opaque automation
