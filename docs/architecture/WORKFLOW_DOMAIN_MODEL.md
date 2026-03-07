# Workflow Domain Model

## Purpose

Phase 7 adds a hybrid workflow layer on top of the append-only decision log so DecisionGraph can operate as a human-in-the-loop control plane.

The event log remains the source of truth for decision history.
Workflow tables add operational state that makes review, escalation, and collaboration queryable without weakening auditability.

## Source Of Truth Split

Event-sourced workflow inputs:
- `ExceptionRequested`
- `ApprovalRecorded`
- `WorkflowReviewRequested`

Operational workflow state:
- reviewer assignment
- inbox ordering and SLA posture
- comments
- request-change actions
- reassign actions
- manual escalations
- notification history
- export views over workflow history

## Core Entities

`workflow item`
- one reviewable operational record tied to a trace and a review subject
- persisted in `dg_workflow_items`
- current subject families:
  - `exception`
  - `trace_review`

`workflow action`
- one human or imported workflow-side action
- persisted in `dg_workflow_actions`
- imported actions come from event-log approvals, exceptions, and trace-review requests
- manual actions include `comment`, `request_change`, `reassign`, and `escalate`

`workflow notification`
- one durable operator-facing signal
- persisted in `dg_workflow_notifications`
- current v1 categories:
  - `assignment`
  - `approval`
  - `deadline_risk`
  - `escalation`
  - `failure`

`workflow runtime cursor`
- tenant-scoped sync checkpoint
- persisted in `dg_workflow_runtime`
- records the highest processed `dg_event_log.log_seq`

## Identity Model

Workflow item ids are deterministic:

`{trace_id}:{subject_type}:{subject_id}`

Examples:
- `trace-123:exception:ex-42`
- `trace-123:trace_review:incident_triage`
- `trace-123:override:trace-123:exception:ex-42`

## Status Model

Workflow item statuses:
- `requested`
- `in_review`
- `changes_requested`
- `escalated`
- `approved`
- `rejected`
- `overridden`

These statuses are enforced in service logic and documented in [WORKFLOW_STATE_MACHINE.md](../reference/WORKFLOW_STATE_MACHINE.md).

## Tenant And Environment Boundaries

All workflow tables are tenant-scoped:
- `dg_workflow_runtime.tenant_id`
- `dg_workflow_items.tenant_id`
- `dg_workflow_actions.tenant_id`
- `dg_workflow_notifications.tenant_id`

Operator permissions are evaluated against the authenticated service account plus tenant scope.

Workflow defaults are deployment-scoped through `:dg_api, :workflow_defaults`, including:
- review SLA hours
- escalation assignment targets
- deadline-risk warning window

## Trace And Projection Links

Workflow items connect back to:
- `trace_id` in `dg_event_log`
- `dg_trace_summary` for title and workflow context when available
- precedent and policy context derived from the existing projection-backed services

This keeps the operator journey coherent:

`workflow item -> trace -> policy review -> precedents -> replay`

## Current Phase 7 Scope

Implemented:
- exception approval queue creation from `ExceptionRequested`
- reviewer inbox and filtering
- approve, reject, request-change, reassign, comment, escalate, and override actions
- workflow studio dry-run and trace-review creation via `WorkflowReviewRequested`
- SLA risk notifications and automatic escalation
- durable operator notification history
- audit export surface for workflow history

Still intentionally limited:
- no external notification delivery
- no multi-step quorum or dual control
- no arbitrary user-authored workflow templates
- no evidence blob storage beyond metadata and locators
