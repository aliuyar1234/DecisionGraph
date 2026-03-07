# Phase 10 Execution Plan

## Purpose

This file turns Phase 10 from [DECISIONGRAPH_BEAM_MASTERPLAN.md](DECISIONGRAPH_BEAM_MASTERPLAN.md) into an active execution checklist.

Phase 10 is about productization and launch: packaging the platform, closing the last operational gaps, building impressive demo material, and shipping a release that feels memorable and credible.

## Phase Goal

By the end of Phase 10 we should have:

- a clear deploy story for self-hosted and optional hosted operation
- installation, upgrade, and production runbook documentation
- a polished demo environment and showcase narrative
- beta feedback incorporated into the release shape
- versioning, release, and migration policy locked in
- the first serious public or internal platform release

## Status

Current phase:
- [ ] Phase 10 active

Phase complete:
- [ ] Phase 10 complete

## Dependencies

Phase 10 depends on these earlier checkpoints:

- [x] Phase 0 direction and scope are frozen
- [x] Phase 1 semantic reference is frozen
- [x] Phase 2 Elixir umbrella foundation is in place
- [x] Phase 3 BEAM event store is in place
- [ ] Phases 4 through 8 are complete enough for real product operation
- [ ] Phase 9 authority decision is recorded or explicitly deferred with rationale
- [ ] Phase 10 execution is approved and started

## Workstreams

- deployment, installation, and upgrade story
- release governance and operational readiness
- docs, demo, and showcase assets
- beta feedback and product gap closure
- launch execution and post-launch follow-through

## Workstream 1 - Deployment, Installation, and Upgrade Story

Goal:
- make adoption practical for real users instead of only for repo insiders

Tasks:
- [ ] define the supported deployment topologies for self-hosted and optional hosted operation
- [ ] finalize installation guides for local evaluation and production deployment
- [ ] finalize configuration guides for auth, storage, observability, and workflow features
- [ ] define upgrade and rollback procedures across platform versions
- [ ] define database migration expectations and support rules
- [ ] package any reference deployment assets, templates, or container guidance needed for evaluation

Deliverables:
- [ ] installation guide in `docs/install/`
- [ ] deployment guide in `docs/operations/DEPLOYMENT_GUIDE.md`
- [ ] upgrade guide in `docs/operations/UPGRADE_AND_ROLLBACK.md`

Acceptance Criteria:
- [ ] a new evaluator can install and run the platform without private tribal knowledge
- [ ] supported deployment topologies are documented clearly enough that self-hosted adoption is realistic
- [ ] upgrade and rollback guidance is specific enough to be used during a real production change window

## Workstream 2 - Release Governance and Operational Readiness

Goal:
- make the release process itself disciplined and repeatable

Tasks:
- [ ] finalize versioning policy for APIs, workflows, and migration behavior
- [ ] finalize release criteria and quality gates
- [ ] finalize production runbooks for incidents, replay recovery, and degraded projections
- [ ] define support expectations for beta and first-release users
- [ ] define security-response and hotfix process
- [ ] define release sign-off roles and evidence requirements

Deliverables:
- [ ] release policy in `docs/release/PLATFORM_RELEASE_POLICY.md`
- [ ] runbook index in `docs/operations/`
- [ ] launch readiness checklist in `docs/release/LAUNCH_READINESS.md`

Acceptance Criteria:
- [ ] release quality gates are explicit enough to block launches that are technically incomplete or operationally unsafe
- [ ] production runbooks cover the highest-risk failure modes introduced in earlier phases
- [ ] support, security-response, and sign-off expectations are defined before the first serious release is cut

## Workstream 3 - Docs, Demo, and Showcase Assets

Goal:
- make the platform easy to understand and hard to ignore

Tasks:
- [ ] finalize operator docs and developer docs
- [ ] create a polished demo environment with realistic traces, workflows, and failures
- [ ] create benchmark and resilience showcase materials
- [ ] create screenshot, walkthrough, and architecture story assets
- [ ] refine the product narrative so differentiators are obvious quickly
- [ ] ensure the demo aligns with the Phase 0 north star and personas

Deliverables:
- [ ] polished demo package and seed data
- [ ] showcase docs in `docs/demo/`
- [ ] updated README and top-level product positioning

Acceptance Criteria:
- [ ] the demo environment shows the platform's strongest capabilities with realistic traces, failures, and workflows
- [ ] docs and showcase materials explain why the product is differentiated within a few minutes of reading or viewing
- [ ] the launch narrative stays aligned with the product north star rather than drifting into generic platform marketing

## Workstream 4 - Beta Feedback and Product Gap Closure

Goal:
- let real usage sharpen the release before launch is declared complete

Tasks:
- [ ] define the beta audience and evaluation criteria
- [ ] run beta or internal pilot sessions
- [ ] collect and triage feedback from operators, platform teams, and compliance users
- [ ] close the highest-signal product gaps found during beta
- [ ] document known limitations that remain acceptable for release
- [ ] refine onboarding and support materials based on real friction

Deliverables:
- [ ] beta feedback tracker or summary report
- [ ] prioritized post-beta change list
- [ ] release caveats documented clearly

Acceptance Criteria:
- [ ] beta feedback comes from the operator, platform, or compliance personas defined earlier rather than only internal implementers
- [ ] the highest-signal feedback is translated into product changes, not only logged as future ideas
- [ ] remaining limitations are documented honestly enough that the first release is not oversold

## Workstream 5 - Launch Execution and Post-Launch Follow-Through

Goal:
- ship with intention and keep the first release stable after it lands

Tasks:
- [ ] cut the first serious platform release
- [ ] publish release notes and upgrade notes
- [ ] validate the release on the target deployment paths
- [ ] monitor early adoption signals and operational metrics closely
- [ ] triage and fix immediate post-launch issues
- [ ] capture the next-wave roadmap informed by launch outcomes

Deliverables:
- [ ] tagged platform release
- [ ] release notes package
- [ ] post-launch review in `docs/release/POST_LAUNCH_REVIEW.md`

Acceptance Criteria:
- [ ] the first release is shipped with release notes, migration guidance, and deployment validation evidence
- [ ] early post-launch monitoring and issue triage are active rather than deferred
- [ ] launch outcomes are turned into a concrete next-wave roadmap instead of being treated as the finish line

## Reference Inputs

Phase 10 should stay aligned with these earlier assets:

- `docs/vision/PRODUCT_NORTH_STAR.md`
- `docs/product/PERSONAS.md`
- `docs/product/V1_PLATFORM_SCOPE.md`
- `docs/product/DEMO_SCENARIO.md`
- `DECISIONGRAPH_PHOENIX_ARCHITECTURE.md`

Launch work should sharpen the existing product direction, not redefine it.

## Validation

Phase 10 should be validated with:

- install and deployment dry runs using the documented paths
- launch-readiness review against the defined release gates
- demo walkthroughs using the final showcase environment
- beta feedback review showing what changed before release

## Required Evidence

Phase 10 should not be accepted without:

- installation, deployment, and upgrade docs that have been exercised
- a completed launch-readiness checklist and release policy
- demo and showcase materials tied to realistic platform behavior
- a tagged release, release notes, and a documented post-launch review

## Exit Criteria

Phase 10 is complete only when:

- [ ] a real release has been cut and documented
- [ ] installation, deployment, upgrade, and runbook docs are credible
- [ ] the demo and showcase materials make the platform feel impressive quickly
- [ ] beta feedback has materially shaped the release
- [ ] post-launch support expectations and follow-through are defined
- [ ] the platform can be presented confidently as a standout product

## Recommended Execution Order

1. deployment, installation, and upgrade story
2. release governance and operational readiness
3. docs, demo, and showcase assets
4. beta feedback and product gap closure
5. launch execution and post-launch follow-through

## Immediate Next Actions

- [ ] define the first supported release topology and packaging targets
- [ ] assemble the release readiness checklist and required evidence
- [ ] build the first polished demo dataset and walkthrough
- [ ] identify the first beta users or internal stakeholders
- [ ] draft the first release-note template and migration guidance

## Notes

Rules for this phase:

- do not confuse a polished demo with a launch-ready platform
- do not ship without clear upgrade and rollback guidance
- treat beta feedback as product input, not as a marketing exercise
- keep the launch narrative anchored in real platform strengths: determinism, replay, investigation, and operational control
