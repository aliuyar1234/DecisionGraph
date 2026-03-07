# Phase 8 Execution Plan

## Purpose

This file turns Phase 8 from [DECISIONGRAPH_BEAM_MASTERPLAN.md](DECISIONGRAPH_BEAM_MASTERPLAN.md) into an active execution checklist.

Phase 8 is about making DecisionGraph operationally credible for local-first, self-hosted use.
The target is not a SaaS control plane.
The target is a GitHub-downloadable system that an operator can install, run, back up, upgrade, and recover on a laptop, workstation, home server, or small VPS without guesswork.

## Phase Goal

By the end of Phase 8 we should have:

- one clearly supported self-hosted topology
- straightforward install and bootstrap paths
- documented backup, restore, retention, and upgrade procedures
- single-node crash, restart, and replay recovery behavior understood and tested
- local-hosting performance targets and hardware guidance
- packaging, release, and validation steps that make GitHub distribution realistic

## Status

Current phase:
- [x] Phase 8 active

Phase complete:
- [x] Phase 8 complete

## Dependencies

Phase 8 depends on these earlier checkpoints:

- [x] Phase 0 direction and scope are frozen
- [x] Phase 1 semantic reference is frozen
- [x] Phase 2 Elixir umbrella foundation is in place
- [x] Phase 3 BEAM event store is in place
- [x] Phase 4 projection runtime is stable enough for self-hosted recovery work
- [x] Phase 5 service API is stable enough for operator-facing install and backup guidance
- [x] Phase 6 operator console is operationally useful on a single-node deployment
- [x] Phase 7 workflow layer is stable enough for self-hosted operator use
- [x] Phase 8 execution is approved and started

## Workstreams

- supported self-hosted topology and install story
- data lifecycle, backup, restore, and upgrade safety
- single-node runtime recovery and restart behavior
- observability, sizing, and performance envelopes
- packaging, release validation, and distribution UX

## Workstream 1 - Supported Self-Hosted Topology And Install Story

Goal:
- define the default way GitHub users are expected to run the system

Tasks:
- [x] define the first officially supported deployment topology
- [x] decide what is mandatory versus optional in the first self-hosted install
- [x] define the recommended local and small-server deployment path
- [x] define auth defaults and operator bootstrap expectations for self-hosted installs
- [x] document supported operating assumptions clearly
- [x] validate that a fresh operator can bootstrap the system from repo docs without hidden tribal knowledge

Deliverables:
- [x] supported topology doc in `docs/architecture/SELF_HOSTED_TOPOLOGY.md`
- [x] install and bootstrap guide in `docs/operations/SELF_HOSTED_INSTALL.md`
- [x] bootstrap validation checklist for a clean machine in `docs/operations/SELF_HOSTED_INSTALL.md`

Acceptance Criteria:
- [x] there is one default install story instead of several half-supported ones
- [x] operators can tell what they need to run before reading source code
- [x] the recommended self-hosted path is validated end to end on a fresh environment

## Workstream 2 - Data Lifecycle, Backup, Restore, And Upgrade Safety

Goal:
- make long-term operation survivable for self-hosted users

Tasks:
- [x] define backup cadence and restore expectations for Postgres-backed installs
- [x] define retention, archival, and pruning policy for local-first use
- [x] define how projection rebuild interacts with retention and backup
- [x] define upgrade and migration expectations between tagged releases
- [x] define rollback guidance for failed upgrades
- [x] document how exported audit records fit into backup and recovery expectations

Deliverables:
- [x] storage lifecycle plan in `docs/architecture/STORAGE_LIFECYCLE.md`
- [x] backup and restore runbook in `docs/operations/BACKUP_AND_RESTORE.md`
- [x] upgrade and rollback guide in `docs/operations/UPGRADE_AND_ROLLBACK.md`

Acceptance Criteria:
- [x] the platform has a documented answer for backup, restore, retention, and upgrade instead of leaving them to operator improvisation
- [x] rebuild, restore, and rollback behavior are explained in terms a self-hosted operator can follow
- [x] data lifecycle guidance preserves replay and audit promises well enough for the product claim

## Workstream 3 - Single-Node Runtime Recovery And Restart Behavior

Goal:
- make the default self-hosted deployment trustworthy under ordinary failure

Tasks:
- [x] define restart behavior for store, projector, API, and workflow components on one node
- [x] define crash recovery expectations for projector workers and replay jobs
- [x] define recovery behavior after interrupted writes, replays, and workflow actions
- [x] define what "healthy after restart" means for the supported topology
- [x] run restart and recovery drills for the supported topology
- [x] document what manual operator actions are still required in failure scenarios

Deliverables:
- [x] recovery behavior doc in `docs/architecture/SINGLE_NODE_RECOVERY.md`
- [x] disaster and restart runbook in `docs/operations/DISASTER_RECOVERY.md`
- [x] tested restart and recovery checklist in `docs/operations/RESTART_AND_RECOVERY_CHECKLIST.md`

Acceptance Criteria:
- [x] the supported deployment has explicit restart and recovery behavior for store, projector, API, and workflow components
- [x] projector and replay recovery are documented and tested rather than assumed
- [x] recovery drills have been run and captured with concrete findings

## Workstream 4 - Observability, Sizing, And Performance Envelopes

Goal:
- give self-hosted operators a realistic idea of what the system needs and how it behaves

Tasks:
- [x] define performance targets for local and small-server installs
- [x] define metrics, logs, and console views that matter for self-hosted operation
- [x] define alerting or operator-watch guidance appropriate for single-node installs
- [x] estimate hardware needs for realistic trace and workflow volumes
- [x] define benchmark profiles future releases must continue to track
- [x] document the main resource and cost drivers for self-hosted operation

Deliverables:
- [x] self-hosted performance targets in `docs/operations/SLOS_AND_ALERTING.md`
- [x] observability guidance in `docs/operations/OBSERVABILITY_DASHBOARDS.md`
- [x] hardware and sizing notes in `docs/benchmarks/PHASE_8_CAPACITY_MODEL.md`

Acceptance Criteria:
- [x] operators have realistic guidance for CPU, memory, disk, and database posture
- [x] benchmark profiles reflect the default self-hosted topology instead of an abstract production cluster
- [x] observability guidance is specific enough that operators can tell whether the node is healthy

## Workstream 5 - Packaging, Release Validation, And Distribution UX

Goal:
- make GitHub distribution feel intentional instead of "clone this and good luck"

Tasks:
- [x] define release artifacts for self-hosted users
- [x] define Docker and non-Docker entry paths if both are supported
- [x] validate install, upgrade, backup, restore, and restart paths from release artifacts
- [x] define release gates for self-hosted safety
- [x] capture known limitations and unsupported topologies clearly
- [x] define the operator-facing release checklist needed before Phase 10 launch work

Deliverables:
- [x] self-hosted release checklist in `docs/operations/SELF_HOSTED_RELEASE_CHECKLIST.md`
- [x] release validation notes in `docs/benchmarks/PHASE_8_RESILIENCE_BASELINE.md`
- [x] distribution guidance for GitHub users in `docs/operations/SELF_HOSTED_INSTALL.md`

Acceptance Criteria:
- [x] a GitHub user can understand how to install and operate the system without reverse-engineering the repo
- [x] release validation covers install, upgrade, restart, and restore paths
- [x] unsupported or deferred topologies are stated plainly instead of implied

## Deferred For Later Hosted Or Enterprise Work

These items are intentionally deferred unless the product direction changes toward hosted or enterprise multi-tenant operation:

- organization, workspace, and environment hierarchy
- strong cross-tenant isolation work beyond the current local/self-hosted auth model
- multi-node clustering and distributed worker ownership
- hosted-service cost modeling
- tenant hotspot dashboards and shared-environment abuse controls

If those become important later, they should return as a dedicated hosted-operations phase instead of distorting the local-first roadmap.

## Reference Inputs

Phase 8 should stay aligned with these earlier assets:

- `docs/product/V1_PLATFORM_SCOPE.md`
- `docs/operations/API_RUNTIME.md`
- `docs/operations/PROJECTION_RUNTIME.md`
- `docs/operations/WORKFLOW_RUNTIME.md`
- `docs/architecture/DECISIONGRAPH_PHOENIX_ARCHITECTURE.md`

This phase is about hardening the existing product shape for self-hosted use, not turning it into a SaaS platform.

## Validation

Phase 8 should be validated with:

- fresh-machine install and bootstrap tests
- backup, restore, and upgrade drills
- restart and recovery drills for the supported topology
- local-hosting benchmarks with captured findings
- release-checklist review tied to the actual GitHub distribution path

## Required Evidence

Phase 8 should not be accepted without:

- a supported self-hosted topology doc plus an install guide
- backup, restore, upgrade, and recovery runbooks
- benchmark and resilience notes in `docs/benchmarks/PHASE_8_CAPACITY_MODEL.md` and `docs/benchmarks/PHASE_8_RESILIENCE_BASELINE.md`
- a release checklist that makes self-hosted distribution credible

## Exit Criteria

Phase 8 is complete only when:

- [x] the default self-hosted topology is clearly defined and documented
- [x] install, backup, restore, and upgrade paths are documented and validated
- [x] single-node restart and recovery behavior is understood well enough for real operators
- [x] performance targets and sizing guidance exist for local and small-server installs
- [x] release validation exposes and addresses major self-hosted reliability risks
- [x] the platform can be described as GitHub-downloadable and self-hostable without hand-waving

## Recommended Execution Order

1. supported self-hosted topology and install story
2. data lifecycle, backup, restore, and upgrade safety
3. single-node runtime recovery and restart behavior
4. observability, sizing, and performance envelopes
5. packaging, release validation, and distribution UX

## Immediate Next Actions

- [x] write the supported self-hosted topology decision record
- [x] write the first install and bootstrap guide
- [x] sketch backup, restore, and upgrade expectations for the default topology
- [x] define the first restart and recovery drill for a single-node install
- [x] run the first local-hosting benchmark profile to find immediate bottlenecks

## Notes

Rules for this phase:

- do not pretend local-first distribution is the same thing as SaaS readiness
- prefer one well-supported self-hosted topology over several weakly supported ones
- do not postpone backup, restore, and upgrade guidance until launch week
- keep reliability claims grounded in drills, benchmarks, and release validation
