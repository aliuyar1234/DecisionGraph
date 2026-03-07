# Phase 8 Execution Plan

## Purpose

This file turns Phase 8 from [DECISIONGRAPH_BEAM_MASTERPLAN.md](DECISIONGRAPH_BEAM_MASTERPLAN.md) into an active execution checklist.

Phase 8 is about making DecisionGraph operationally credible for serious production use through multi-tenancy, reliability engineering, scale planning, and recovery discipline.

## Phase Goal

By the end of Phase 8 we should have:

- clear organization, workspace, and environment isolation
- tenant-scoped event and projection boundaries
- defined partitioning, retention, backup, and recovery strategy
- clustering and multi-node runtime plans for BEAM deployment
- performance targets, SLOs, and observability dashboards
- evidence from failover, recovery, and chaos-style validation

## Status

Current phase:
- [ ] Phase 8 active

Phase complete:
- [ ] Phase 8 complete

## Dependencies

Phase 8 depends on these earlier checkpoints:

- [x] Phase 0 direction and scope are frozen
- [x] Phase 1 semantic reference is frozen
- [x] Phase 2 Elixir umbrella foundation is in place
- [x] Phase 3 BEAM event store is in place
- [ ] Phase 4 projection runtime is production-credible
- [ ] Phase 5 service API is production-credible
- [ ] Phase 6 operator console is operationally useful
- [ ] Phase 7 workflow layer is stable enough for multi-tenant operation
- [ ] Phase 8 execution is approved and started

## Workstreams

- tenancy and isolation model
- data lifecycle and storage strategy
- distributed runtime, failover, and recovery
- SLOs, observability, and capacity planning
- chaos, scale, and operational validation

## Workstream 1 - Tenancy and Isolation Model

Goal:
- define the isolation boundaries that make shared environments safe and understandable

Tasks:
- [ ] define organization, workspace, environment, and service-account boundaries
- [ ] decide what isolation is logical versus physical in the first production model
- [ ] define tenant-scoped event, projection, workflow, and admin boundaries
- [ ] define naming, routing, and auth rules for tenant-scoped resources
- [ ] document cross-tenant access prohibitions and rare exception cases
- [ ] add tests that prove tenant isolation at API, query, and workflow layers

Deliverables:
- [ ] tenancy model doc in `docs/architecture/TENANCY_MODEL.md`
- [ ] tenant boundary implementation notes in `docs/operations/TENANT_ISOLATION.md`
- [ ] isolation test coverage across service and UI layers

Acceptance Criteria:
- [ ] tenant and environment boundaries are explicit enough that API, query, workflow, and UI paths all enforce the same isolation model
- [ ] cross-tenant access is blocked by default and only documented exceptions exist where absolutely necessary
- [ ] isolation behavior is proven by tests instead of being implied by naming or convention

## Workstream 2 - Data Lifecycle and Storage Strategy

Goal:
- make long-term data growth, retention, and recovery explicit

Tasks:
- [ ] define partitioning strategy for high-growth event tables
- [ ] define archival, retention, and pruning policies for events and projections
- [ ] define backup cadence and restore expectations
- [ ] decide how projection rebuild interacts with archival and retention
- [ ] define evidence-preserving export strategy for compliance and incident response
- [ ] document local-dev versus production database expectations clearly

Deliverables:
- [ ] storage lifecycle plan in `docs/architecture/STORAGE_LIFECYCLE.md`
- [ ] archival and retention runbook in `docs/operations/DATA_RETENTION_AND_ARCHIVE.md`
- [ ] migration or partitioning plan for production growth

Acceptance Criteria:
- [ ] the platform has a documented answer for growth, retention, backup, and restore instead of treating them as future concerns
- [ ] partitioning and archival strategy preserve replay and audit requirements well enough for the product promise
- [ ] operators can understand what data is kept, moved, restored, or pruned without reading code

## Workstream 3 - Distributed Runtime, Failover, and Recovery

Goal:
- make the BEAM runtime survivable under node loss and dependency disruption

Tasks:
- [ ] define single-node versus multi-node deployment topologies
- [ ] define clustering strategy for Phoenix, PubSub, and background workers
- [ ] define projection worker ownership and reassignment in multi-node conditions
- [ ] define failover and restart behavior for store, projector, API, and workflow components
- [ ] define disaster-recovery procedures for database loss, projection corruption, and deployment rollback
- [ ] run failover and recovery drills for the first supported topology

Deliverables:
- [ ] clustering and failover doc in `docs/architecture/BEAM_CLUSTERING_AND_FAILOVER.md`
- [ ] recovery runbook in `docs/operations/DISASTER_RECOVERY.md`
- [ ] tested recovery drill checklist

Acceptance Criteria:
- [ ] the first supported deployment topology has explicit failover and restart behavior for store, projector, API, and workflow components
- [ ] worker ownership and reassignment rules in multi-node conditions are clear enough to avoid split-brain projection behavior
- [ ] recovery drills have been executed and documented rather than planned abstractly

## Workstream 4 - SLOs, Observability, and Capacity Planning

Goal:
- know what good and bad platform behavior looks like before production pressure arrives

Tasks:
- [ ] define service-level objectives for write availability, projection lag, replay duration, and workflow responsiveness
- [ ] define metrics and dashboards for throughput, lag, queue depth, error rates, and tenant hotspots
- [ ] define alert thresholds and escalation expectations
- [ ] estimate capacity needs for realistic tenant and trace volumes
- [ ] document operational cost drivers for storage, replay, and realtime workloads
- [ ] define benchmark profiles that future releases must track

Deliverables:
- [ ] SLO doc in `docs/operations/SLOS_AND_ALERTING.md`
- [ ] dashboard specification in `docs/operations/OBSERVABILITY_DASHBOARDS.md`
- [ ] capacity notes in `docs/benchmarks/PHASE_8_CAPACITY_MODEL.md`

Acceptance Criteria:
- [ ] service-level objectives exist for the most important platform promises, including writes, projection lag, replay, and workflow responsiveness
- [ ] dashboards and alerts are specific enough that operators can tell what is broken and who is impacted
- [ ] capacity notes include realistic workload assumptions instead of only synthetic best-case numbers

## Workstream 5 - Chaos, Scale, and Operational Validation

Goal:
- replace hopeful assumptions with evidence under stress

Tasks:
- [ ] run load tests for event ingestion, projection catch-up, search, and workflow activity
- [ ] run chaos-style tests for worker crashes, database disruptions, and dependency timeouts
- [ ] run recovery tests for node restarts and replay after interruption
- [ ] capture scaling limits and known failure modes explicitly
- [ ] define release gates for operational safety
- [ ] record remediation plans for any unacceptable bottlenecks discovered

Deliverables:
- [ ] load and chaos validation suite
- [ ] scale and resilience notes in `docs/benchmarks/PHASE_8_RESILIENCE_BASELINE.md`
- [ ] operational readiness checklist for Phase 10 launch work

Acceptance Criteria:
- [ ] scale testing identifies bottlenecks in ingestion, projection, search, or workflow paths before launch planning begins
- [ ] chaos and recovery tests produce concrete findings and remediation items, not only pass/fail badges
- [ ] operational readiness gates are explicit enough that later launch work can say no to an unsafe release

## Reference Inputs

Phase 8 should stay aligned with these earlier assets:

- `docs/product/V1_PLATFORM_SCOPE.md`
- `docs/operations/API_RUNTIME.md`
- `docs/operations/PROJECTION_RUNTIME.md`
- `docs/operations/WORKFLOW_RUNTIME.md`
- `DECISIONGRAPH_PHOENIX_ARCHITECTURE.md`

This phase is about hardening the existing product shape, not changing the fundamental semantic model.

## Validation

Phase 8 should be validated with:

- tenant-isolation tests across API, query, workflow, and UI paths
- restore and recovery drills for the first supported deployment topology
- load, chaos, and failover exercises with captured findings
- SLO, dashboard, and alert reviews tied to real workload assumptions

## Required Evidence

Phase 8 should not be accepted without:

- tenancy and isolation docs plus supporting tests
- storage lifecycle, retention, backup, and disaster-recovery runbooks
- benchmark and resilience notes in `docs/benchmarks/PHASE_8_CAPACITY_MODEL.md` and `docs/benchmarks/PHASE_8_RESILIENCE_BASELINE.md`
- an operational readiness checklist for launch gating

## Exit Criteria

Phase 8 is complete only when:

- [ ] tenant and environment isolation are clearly defined and validated
- [ ] data growth, retention, backup, and recovery strategy are documented and tested
- [ ] multi-node or failover behavior is understood well enough for real operations
- [ ] SLOs, dashboards, and alerting expectations are defined
- [ ] scale and chaos tests have exposed and addressed major reliability risks
- [ ] the platform can be described as operationally credible without hand-waving

## Recommended Execution Order

1. tenancy and isolation model
2. data lifecycle and storage strategy
3. distributed runtime, failover, and recovery
4. SLOs, observability, and capacity planning
5. chaos, scale, and operational validation

## Immediate Next Actions

- [ ] write the tenancy and isolation decision record
- [ ] sketch the production partitioning and retention strategy
- [ ] define the first supported deployment topology and failover model
- [ ] establish SLO candidates for ingestion, projection lag, and replay
- [ ] run the first scale test profile to find immediate bottlenecks

## Notes

Rules for this phase:

- do not claim multi-tenant readiness without explicit boundary tests
- do not postpone recovery thinking until launch week
- prefer tested operational constraints over vague scalability claims
- keep production credibility grounded in observable evidence
