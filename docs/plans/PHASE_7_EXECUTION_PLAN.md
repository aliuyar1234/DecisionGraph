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
- [x] Phase 7 active

Phase complete:
- [x] Phase 7 complete

## Dependencies

Phase 7 depends on these earlier checkpoints:

- [x] Phase 0 direction and scope are frozen
- [x] Phase 1 semantic reference is frozen
- [x] Phase 2 Elixir umbrella foundation is in place
- [x] Phase 3 BEAM event store is in place
- [x] Phase 4 projection runtime is complete enough to drive workflow context
- [x] Phase 5 service API is complete enough to expose workflow actions
- [x] Phase 6 operator console is complete enough to host workflow UX
- [x] Phase 7 execution is approved and started

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
- [x] define the workflow entities for approvals, exception requests, escalations, comments, evidence, overrides, and SLA timers
- [x] decide what is event-sourced versus what is stored as operational workflow state
- [x] define status models and legal transitions for each workflow type
- [x] design workflow tables, indexes, and migration strategy
- [x] define tenant and environment boundaries for workflow records
- [x] document how workflow records connect back to decision traces and projections

Deliverables:
- [x] workflow domain design in `docs/architecture/WORKFLOW_DOMAIN_MODEL.md`
- [x] workflow persistence migrations and schemas under `beam/apps/`
- [x] status transition rules documented in `docs/reference/WORKFLOW_STATE_MACHINE.md`

Acceptance Criteria:
- [x] workflow states and legal transitions are explicit enough to be tested and enforced mechanically
- [x] workflow records connect cleanly to traces, projections, tenants, and operators without ambiguous ownership
- [x] persistence design supports auditability and queryability without weakening the append-only decision history

## Workstream 2 - Approvals, Inboxes, and Overrides

Goal:
- make human-in-the-loop actions operationally usable

Tasks:
- [x] implement approval queue creation and reviewer assignment
- [x] implement reviewer inboxes with filtering and prioritization
- [x] implement approve, reject, request-change, and reassign flows
- [x] implement manual override flows with strong justification requirements
- [x] define how workflow actions are reflected in the event log and operator UI
- [x] define permission rules for sensitive approvals and overrides

Deliverables:
- [x] approval service modules under `beam/apps/dg_api/`
- [x] approval and inbox UI under `beam/apps/dg_web/`
- [x] override policy notes in `docs/operations/APPROVAL_AND_OVERRIDE_POLICY.md`

Acceptance Criteria:
- [x] reviewers can receive, filter, and act on approval items through a clear inbox flow
- [x] sensitive approvals and overrides enforce stronger permission and justification requirements than ordinary workflow actions
- [x] approval and override actions are reflected in both the operator experience and the audit trail consistently

## Workstream 3 - Escalation, Collaboration, and Notifications

Goal:
- make workflows responsive under time pressure and cross-team review

Tasks:
- [x] implement escalation rules and SLA timers
- [x] implement comments and collaboration history on workflow items
- [x] implement evidence attachment metadata and storage strategy
- [x] implement notifications for approval assignment, escalation, deadline risk, and failure
- [x] decide which notification channels are required for v1
- [x] add audit visibility for collaboration and escalation events

Deliverables:
- [x] notification and escalation modules
- [x] collaboration surfaces in the operator console
- [x] notification behavior guide in `docs/operations/WORKFLOW_NOTIFICATIONS.md`

Acceptance Criteria:
- [x] escalation timing and ownership are deterministic enough that overdue items do not depend on manual watching
- [x] comments, collaboration history, and evidence are visible in enough context to support cross-team review
- [x] notification behavior is constrained and documented well enough to avoid silent failures or alert spam

## Workstream 4 - Simulation, Templates, and Incident Review

Goal:
- turn workflows into reusable operational patterns rather than one-off actions

Tasks:
- [x] implement policy simulation or dry-run workflow entry points
- [x] implement workflow templates for common review processes
- [x] implement replay-plus-review flows for incident analysis
- [x] define how investigators can turn traces into review items quickly
- [x] define how precedent context is shown inside workflow reviews
- [x] capture the first end-to-end human-review demo journey

Deliverables:
- [x] workflow templates and simulation modules
- [x] incident review journey in the operator console
- [x] demo notes in `docs/product/WORKFLOW_DEMO_SCENARIO.md`

Acceptance Criteria:
- [x] teams can start a review from a trace or policy simulation without stitching together unrelated tools
- [x] workflow templates reduce setup friction for the most important review scenarios
- [x] incident review flows connect replay, precedent context, and human review in one coherent journey

## Workstream 5 - Audit, Exports, and Safety Validation

Goal:
- ensure workflow actions are trustworthy under compliance and incident pressure

Tasks:
- [x] implement audit-focused exports for approvals, escalations, comments, and overrides
- [x] define retention and redaction rules for workflow artifacts
- [x] add end-to-end tests for workflow state transitions and audit capture
- [x] add permission and abuse tests for override and escalation paths
- [x] define operational runbooks for stuck workflows and missed SLAs
- [x] capture known limits for the first workflow release

Deliverables:
- [x] export surface for workflow records
- [x] workflow test suite across API and UI layers
- [x] runbook in `docs/operations/WORKFLOW_RUNTIME.md`
- [x] retention guidance in `docs/operations/WORKFLOW_RETENTION_AND_REDACTION.md`

Acceptance Criteria:
- [x] approvals, escalations, comments, and overrides can be exported in an audit-friendly form
- [x] workflow tests prove state transition, permission, and audit behavior end to end
- [x] operators have runbook guidance for stuck workflows, missed SLAs, and first-release limitations

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
- operational guidance in `docs/operations/APPROVAL_AND_OVERRIDE_POLICY.md`, `docs/operations/WORKFLOW_NOTIFICATIONS.md`, `docs/operations/WORKFLOW_RUNTIME.md`, and `docs/operations/WORKFLOW_RETENTION_AND_REDACTION.md`

## Exit Criteria

Phase 7 is complete only when:

- [x] approvals, exceptions, escalations, and overrides are first-class platform flows
- [x] workflow actions are fully audited and exportable
- [x] comments, evidence, and notifications support realistic operator collaboration
- [x] incident review and simulation flows feel integrated rather than bolted on
- [x] permission boundaries for workflow actions are credible
- [x] the platform clearly supports human-in-the-loop decision operations

## Recommended Execution Order

1. workflow domain model and persistence
2. approvals, inboxes, and override flows
3. escalation, collaboration, and notifications
4. simulation, templates, and incident review
5. audit, exports, and safety validation

## Immediate Next Actions

- [x] write the workflow state model and persistence sketch
- [x] implement the first approval queue and reviewer inbox flow
- [x] implement workflow action audit capture
- [x] add escalation and notification rules for a first scenario
- [x] add an end-to-end workflow test tied to the Phase 0 demo scenario

## Notes

Rules for this phase:

- do not add workflow power without equally strong audit capture
- do not treat overrides as informal side paths
- keep workflow states explicit and machine-verifiable
- prefer a smaller, trustworthy workflow surface over a sprawling but weakly governed one
