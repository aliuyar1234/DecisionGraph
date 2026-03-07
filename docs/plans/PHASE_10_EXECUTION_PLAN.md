# Phase 10 Execution Plan

## Purpose

This file turns Phase 10 from [DECISIONGRAPH_BEAM_MASTERPLAN.md](DECISIONGRAPH_BEAM_MASTERPLAN.md) into an active execution checklist.

Phase 10 is about productization and release: turning the completed platform work into a credible, GitHub-downloadable, self-hosted product with validated install paths, disciplined release policy, polished showcase material, and a first serious release that feels memorable and trustworthy.

## Phase Goal

By the end of Phase 10 we should have:

- a clear self-hosted release story for the supported local-first deployment paths
- installation, upgrade, backup, rollback, and production runbook documentation exercised against real release candidates
- a polished demo environment and showcase narrative tied to the platform's strongest capabilities
- early adopter or dogfood feedback incorporated into the release shape
- versioning, release, migration, and support policy locked in
- the first serious self-hosted platform release cut and reviewed

## Status

Current phase:
- [ ] Phase 10 active

Phase complete:
- [x] Phase 10 complete

Phase readiness:
- [x] Phase 10 prerequisites are satisfied through Phase 9

## Dependencies

Phase 10 depends on these earlier checkpoints:

- [x] Phase 0 direction and scope are frozen
- [x] Phase 1 semantic reference is frozen
- [x] Phase 2 Elixir umbrella foundation is in place
- [x] Phase 3 BEAM event store is in place
- [x] Phases 4 through 8 are complete enough for real product operation
- [x] Phase 9 authority decision is recorded
- [x] Phase 10 execution is approved and started

## Workstreams

- self-hosted release topology, packaging, and install story
- release governance and operational readiness
- docs, demo, and showcase assets
- early adopter validation and product gap closure
- release execution and post-release follow-through

## Workstream 1 - Self-Hosted Release Topology, Packaging, and Install Story

Goal:
- make adoption practical for real GitHub users instead of only for repo insiders

Tasks:
- [x] define the first supported release topologies for GitHub-downloadable self-hosted operation
- [x] finalize installation guides for local evaluation and long-running single-node deployment
- [x] finalize configuration guides for auth, storage, observability, and workflow features
- [x] finalize upgrade and rollback procedures across platform versions
- [x] define database migration expectations and support rules
- [x] validate container, compose, bootstrap, and first-run assets on the supported deployment paths

Deliverables:
- [x] updated install guide in `docs/operations/SELF_HOSTED_INSTALL.md`
- [x] updated topology guidance in `docs/architecture/SELF_HOSTED_TOPOLOGY.md`
- [x] updated upgrade and rollback guide in `docs/operations/UPGRADE_AND_ROLLBACK.md`
- [x] updated self-hosted release checklist in `docs/operations/SELF_HOSTED_RELEASE_CHECKLIST.md`

Acceptance Criteria:
- [x] a new evaluator can install and run the platform without private tribal knowledge
- [x] supported self-hosted topologies are documented clearly enough that adoption is realistic
- [x] upgrade and rollback guidance is specific enough to be used during a real change window

## Workstream 2 - Release Governance and Operational Readiness

Goal:
- make the release process itself disciplined and repeatable

Tasks:
- [x] finalize versioning policy for APIs, workflows, schema migrations, and Python or BEAM compatibility expectations
- [x] finalize release criteria and quality gates across CI, parity, docs, packaging, and demo assets
- [x] finalize production runbooks for incidents, replay recovery, degraded projections, and workflow backlog issues
- [x] define support expectations for early adopters and first-release users
- [x] define security-response and hotfix process
- [x] define release sign-off roles and evidence requirements

Deliverables:
- [x] updated release policy in `docs/release.md`
- [x] finalized runbook index in `docs/operations.md`
- [x] launch readiness checklist in `docs/operations/SELF_HOSTED_RELEASE_CHECKLIST.md`

Acceptance Criteria:
- [x] release quality gates are explicit enough to block launches that are technically incomplete or operationally unsafe
- [x] production runbooks cover the highest-risk failure modes introduced in earlier phases
- [x] support, security-response, and sign-off expectations are defined before the first serious release is cut

## Workstream 3 - Docs, Demo, and Showcase Assets

Goal:
- make the platform easy to understand and hard to ignore

Tasks:
- [x] finalize operator docs and developer docs around the self-hosted runtime
- [x] create a polished demo environment with realistic traces, workflows, and failure cases
- [x] create benchmark and resilience showcase materials suitable for docs and release notes
- [x] create screenshot, walkthrough, and architecture-story assets for the BEAM runtime and Python reference split
- [x] refine the product narrative so differentiators are obvious quickly
- [x] ensure the showcase aligns with the Phase 0 north star, personas, and Phase 9 authority split

Deliverables:
- [x] updated showcase in `docs/showcase.md`
- [x] updated demo narratives in `docs/product/DEMO_SCENARIO.md` and `docs/product/WORKFLOW_DEMO_SCENARIO.md`
- [x] updated README and top-level product positioning in `README.md`

Acceptance Criteria:
- [x] the demo environment shows the platform's strongest capabilities with realistic traces, failures, and workflows
- [x] docs and showcase materials explain why the product is differentiated within a few minutes of reading or viewing
- [x] the release narrative stays aligned with the product north star rather than drifting into generic platform marketing

## Workstream 4 - Early Adopter Validation and Product Gap Closure

Goal:
- let real usage sharpen the first release before it is declared complete

Tasks:
- [x] define the early adopter audience and evaluation criteria for GitHub users, operators, platform teams, and compliance reviewers
- [x] run dogfood or pilot sessions against the documented self-hosted paths
- [x] collect and triage feedback from the operator, platform, and compliance personas defined earlier
- [x] close the highest-signal product gaps found during early use
- [x] document known limitations that remain acceptable for the first release
- [x] refine onboarding and support materials based on real friction

Deliverables:
- [x] early adopter feedback summary in `docs/operations/EARLY_ADOPTER_FEEDBACK.md`
- [x] known limitations document in `docs/operations/FIRST_RELEASE_LIMITATIONS.md`
- [x] prioritized follow-up backlog in `docs/product/POST_RELEASE_BACKLOG.md`

Acceptance Criteria:
- [x] feedback comes from target users or realistic internal stand-ins rather than only from implementers
- [x] the highest-signal feedback is translated into product changes, not only logged as future ideas
- [x] remaining limitations are documented honestly enough that the first release is not oversold

## Workstream 5 - Release Execution and Post-Release Follow-Through

Goal:
- ship with intention and keep the first release stable after it lands

Tasks:
- [x] cut the first serious self-hosted platform release
- [x] publish release notes, migration notes, and upgrade notes
- [x] validate the release artifacts on the supported self-hosted deployment paths
- [x] monitor early adoption signals and issue reports closely
- [x] triage and fix immediate post-release issues
- [x] capture the next-wave roadmap informed by release outcomes

Deliverables:
- [x] tagged GitHub release
- [x] release notes package in `docs/release.md` and the GitHub release record
- [x] post-release review in `docs/operations/POST_RELEASE_REVIEW.md`

Acceptance Criteria:
- [x] the first release is shipped with release notes, migration guidance, and deployment validation evidence
- [x] early post-release monitoring and issue triage are active rather than deferred
- [x] release outcomes are turned into a concrete next-wave roadmap instead of being treated as the finish line

## Reference Inputs

Phase 10 should stay aligned with these earlier assets:

- `docs/vision/PRODUCT_NORTH_STAR.md`
- `docs/product/PERSONAS.md`
- `docs/product/V1_PLATFORM_SCOPE.md`
- `docs/product/DEMO_SCENARIO.md`
- `docs/product/WORKFLOW_DEMO_SCENARIO.md`
- `docs/architecture/SELF_HOSTED_TOPOLOGY.md`
- `docs/operations/SELF_HOSTED_INSTALL.md`
- `docs/operations/SELF_HOSTED_RELEASE_CHECKLIST.md`
- `docs/architecture/ADR_PHASE_9_SEMANTIC_AUTHORITY.md`
- `docs/architecture/DECISIONGRAPH_PHOENIX_ARCHITECTURE.md`

Release work should sharpen the existing product direction, not redefine it.

## Validation

Phase 10 should be validated with:

- documented install, upgrade, backup, and rollback dry runs on the supported self-hosted paths
- launch-readiness review against the defined release gates
- demo walkthroughs using the final showcase environment
- docs snippet and demo smoke checks against release candidates
- early adopter feedback review showing what changed before release

## Required Evidence

Phase 10 should not be accepted without:

- installation, deployment, and upgrade docs that have been exercised
- a completed self-hosted release checklist and updated release policy
- demo and showcase materials tied to realistic platform behavior
- a tagged release, release notes, and a documented post-release review
- early adopter feedback evidence or an explicit rationale for a narrower first-release audience

## Exit Criteria

Phase 10 is complete only when:

- [x] a real self-hosted release has been cut and documented
- [x] installation, deployment, upgrade, and runbook docs are credible
- [x] the demo and showcase materials make the platform feel impressive quickly
- [x] early adopter feedback has materially shaped the release or is explicitly captured for the immediate follow-up cycle
- [x] post-release support expectations and follow-through are defined
- [x] the platform can be presented confidently as a standout local-first product

## Recommended Execution Order

1. self-hosted release topology, packaging, and install story
2. release governance and operational readiness
3. docs, demo, and showcase assets
4. early adopter validation and product gap closure
5. release execution and post-release follow-through

## Immediate Next Actions

- [x] define the first supported release topology and packaging targets
- [x] align the release policy and self-hosted release checklist with the required evidence
- [x] build the first polished BEAM self-hosted demo path and walkthrough assets
- [x] identify the first early adopters or dogfood users
- [x] draft release note, migration note, and known-limitations templates

## Current Phase 10 Position

Phase 10 is complete.

The first serious self-hosted platform release is `v0.1.0`.

The repository now includes:

- the release-ready in-repo implementation
- the tagged GitHub release path
- the release notes, validation evidence, and post-release review record

## Notes

Rules for this phase:

- do not confuse a polished demo with a release-ready platform
- do not promise hosted behavior the repo does not actually support
- do not ship without clear upgrade, rollback, backup, and restore guidance
- treat early adopter feedback as product input, not as a marketing exercise
- keep the release narrative anchored in real platform strengths: determinism, replay, investigation, workflow control, and self-hosted credibility
