# Phase 7 Execution Plan

## Purpose

This file turns Phase 7 from [DECISIONGRAPH_BEAM_MASTERPLAN.md](DECISIONGRAPH_BEAM_MASTERPLAN.md) into an active execution checklist.

Phase 7 is about adding the human approval and workflow layer so DecisionGraph becomes an active decision operations platform rather than only a trace and investigation system.

## Phase Goal

By the end of Phase 7 we should have:

- approval queues and reviewer inboxes
- exception and escalation workflows
- comments, evidence, and override capture with full auditability
- notifications and SLA-aware workflow behavior
- policy simulation and review flows for incident analysis
- exportable workflow audit records

## Status

Current phase:
- [ ] Phase 7 active

Phase complete:
- [ ] Phase 7 complete

## Dependencies

Phase 7 depends on these earlier checkpoints:

- [x] Phase 0 direction and scope are frozen
- [x] Phase 1 semantic reference is frozen
- [x] Phase 2 Elixir umbrella foundation is in place
- [x] Phase 3 BEAM event store is in place
- [ ] Phase 4 projection runtime is complete enough to drive workflow context
- [ ] Phase 5 service API is complete enough to expose workflow actions
- [ ] Phase 6 operator console is complete enough to host workflow UX
- [ ] Phase 7 execution is approved and started

## Workstreams

- workflow domain and data model
- approvals, inboxes, and overrides
- escalation, collaboration, and notifications
- simulation, templates, and incident review
- audit, exports, and safety validation

## Workstream 1 - Workflow Domain and Data Model

Goal:
- define workflow concepts cleanly before building action-heavy UI and API surfaces

Tasks:
- [ ] define the workflow entities for approvals, exception requests, escalations, comments, evidence, overrides, and SLA timers
- [ ] decide what is event-sourced versus what is stored as operational workflow state
- [ ] define status models and legal transitions for each workflow type
- [ ] design workflow tables, indexes, and migration strategy
- [ ] define tenant and environment boundaries for workflow records
- [ ] document how workflow records connect back to decision traces and projections

Deliverables:
- [ ] workflow domain design in `docs/architecture/WORKFLOW_DOMAIN_MODEL.md`
- [ ] workflow persistence migrations and schemas under `beam/apps/`
- [ ] status transition rules documented in `docs/reference/WORKFLOW_STATE_MACHINE.md`

Acceptance Criteria:
- [ ] workflow states and legal transitions are explicit enough to be tested and enforced mechanically
- [ ] workflow records connect cleanly to traces, projections, tenants, and operators without ambiguous ownership
- [ ] persistence design supports auditability and queryability without weakening the append-only decision history

## Workstream 2 - Approvals, Inboxes, and Overrides

Goal:
- make human-in-the-loop actions operationally usable

Tasks:
- [ ] implement approval queue creation and reviewer assignment
- [ ] implement reviewer inboxes with filtering and prioritization
- [ ] implement approve, reject, request-change, and reassign flows
- [ ] implement manual override flows with strong justification requirements
- [ ] define how workflow actions are reflected in the event log and operator UI
- [ ] define permission rules for sensitive approvals and overrides

Deliverables:
- [ ] approval service modules under `beam/apps/dg_api/`
- [ ] approval and inbox UI under `beam/apps/dg_web/`
- [ ] override policy notes in `docs/operations/APPROVAL_AND_OVERRIDE_POLICY.md`

Acceptance Criteria:
- [ ] reviewers can receive, filter, and act on approval items through a clear inbox flow
- [ ] sensitive approvals and overrides enforce stronger permission and justification requirements than ordinary workflow actions
- [ ] approval and override actions are reflected in both the operator experience and the audit trail consistently

## Workstream 3 - Escalation, Collaboration, and Notifications

Goal:
- make workflows responsive under time pressure and cross-team review

Tasks:
- [ ] implement escalation rules and SLA timers
- [ ] implement comments and collaboration history on workflow items
- [ ] implement evidence attachment metadata and storage strategy
- [ ] implement notifications for approval assignment, escalation, deadline risk, and failure
- [ ] decide which notification channels are required for v1
- [ ] add audit visibility for collaboration and escalation events

Deliverables:
- [ ] notification and escalation modules
- [ ] collaboration surfaces in the operator console
- [ ] notification behavior guide in `docs/operations/WORKFLOW_NOTIFICATIONS.md`

Acceptance Criteria:
- [ ] escalation timing and ownership are deterministic enough that overdue items do not depend on manual watching
- [ ] comments, collaboration history, and evidence are visible in enough context to support cross-team review
- [ ] notification behavior is constrained and documented well enough to avoid silent failures or alert spam

## Workstream 4 - Simulation, Templates, and Incident Review

Goal:
- turn workflows into reusable operational patterns rather than one-off actions

Tasks:
- [ ] implement policy simulation or dry-run workflow entry points
- [ ] implement workflow templates for common review processes
- [ ] implement replay-plus-review flows for incident analysis
- [ ] define how investigators can turn traces into review items quickly
- [ ] define how precedent context is shown inside workflow reviews
- [ ] capture the first end-to-end human-review demo journey

Deliverables:
- [ ] workflow templates and simulation modules
- [ ] incident review journey in the operator console
- [ ] demo notes in `docs/product/WORKFLOW_DEMO_SCENARIO.md`

Acceptance Criteria:
- [ ] teams can start a review from a trace or policy simulation without stitching together unrelated tools
- [ ] workflow templates reduce setup friction for the most important review scenarios
- [ ] incident review flows connect replay, precedent context, and human review in one coherent journey

## Workstream 5 - Audit, Exports, and Safety Validation

Goal:
- ensure workflow actions are trustworthy under compliance and incident pressure

Tasks:
- [ ] implement audit-focused exports for approvals, escalations, comments, and overrides
- [ ] define retention and redaction rules for workflow artifacts
- [ ] add end-to-end tests for workflow state transitions and audit capture
- [ ] add permission and abuse tests for override and escalation paths
- [ ] define operational runbooks for stuck workflows and missed SLAs
- [ ] capture known limits for the first workflow release

Deliverables:
- [ ] export surface for workflow records
- [ ] workflow test suite across API and UI layers
- [ ] runbook in `docs/operations/WORKFLOW_RUNTIME.md`

Acceptance Criteria:
- [ ] approvals, escalations, comments, and overrides can be exported in an audit-friendly form
- [ ] workflow tests prove state transition, permission, and audit behavior end to end
- [ ] operators have runbook guidance for stuck workflows, missed SLAs, and first-release limitations

## Reference Inputs

Phase 7 should stay aligned with these existing strategy assets:

- `docs/product/PERSONAS.md`
- `docs/product/V1_PLATFORM_SCOPE.md`
- `docs/product/DEMO_SCENARIO.md`
- `docs/reference/SEMANTIC_PARITY_POLICY.md`

Workflow features may expand the product, but they must preserve the auditability and determinism principles already established.

## Validation

Phase 7 should be validated with:

- end-to-end workflow tests across API and UI layers
- permission and abuse tests for approvals, overrides, and escalation paths
- audit-export checks using realistic workflow histories
- scenario walkthroughs tied to the Phase 0 demo and incident-review flows

## Required Evidence

Phase 7 should not be accepted without:

- a documented workflow state model and transition rules
- working approval and inbox surfaces in the operator console
- audit export capability for workflow actions
- operational guidance in `docs/operations/APPROVAL_AND_OVERRIDE_POLICY.md`, `docs/operations/WORKFLOW_NOTIFICATIONS.md`, and `docs/operations/WORKFLOW_RUNTIME.md`

## Exit Criteria

Phase 7 is complete only when:

- [ ] approvals, exceptions, escalations, and overrides are first-class platform flows
- [ ] workflow actions are fully audited and exportable
- [ ] comments, evidence, and notifications support realistic operator collaboration
- [ ] incident review and simulation flows feel integrated rather than bolted on
- [ ] permission boundaries for workflow actions are credible
- [ ] the platform clearly supports human-in-the-loop decision operations

## Recommended Execution Order

1. workflow domain model and persistence
2. approvals, inboxes, and override flows
3. escalation, collaboration, and notifications
4. simulation, templates, and incident review
5. audit, exports, and safety validation

## Immediate Next Actions

- [ ] write the workflow state model and persistence sketch
- [ ] implement the first approval queue and reviewer inbox flow
- [ ] implement workflow action audit capture
- [ ] add escalation and notification rules for a first scenario
- [ ] add an end-to-end workflow test tied to the Phase 0 demo scenario

## Notes

Rules for this phase:

- do not add workflow power without equally strong audit capture
- do not treat overrides as informal side paths
- keep workflow states explicit and machine-verifiable
- prefer a smaller, trustworthy workflow surface over a sprawling but weakly governed one
