# Workflow State Machine

## Workflow Types

Current Phase 7 workflow types:
- `exception_review`
- `incident_review`

## States

Open states:
- `requested`
- `in_review`
- `changes_requested`
- `escalated`

Terminal states:
- `approved`
- `rejected`
- `overridden`

## Core Transitions

From `requested`:
- `approve` -> `approved`
- `reject` -> `rejected`
- `request_change` -> `changes_requested`
- `comment` -> `requested`
- `reassign` -> `requested`
- `escalate` -> `escalated`
- `override` -> `overridden`

From `changes_requested`:
- `approve` -> `approved`
- `reject` -> `rejected`
- `request_change` -> `changes_requested`
- `comment` -> `changes_requested`
- `reassign` -> `changes_requested`
- `escalate` -> `escalated`
- `override` -> `overridden`

From `escalated`:
- `approve` -> `approved`
- `reject` -> `rejected`
- `request_change` -> `changes_requested`
- `comment` -> `escalated`
- `reassign` -> `escalated`
- repeated `escalate` is rejected
- `override` -> `overridden`

From `approved`, `rejected`, or `overridden`:
- `comment` is still allowed
- all other actions are rejected

## Event Log Reflection

`approve`
- appends `ApprovalRecorded`
- `payload.subject` mirrors the workflow subject
- `payload.decision=approved`

`reject`
- appends `ApprovalRecorded`
- `payload.subject` mirrors the workflow subject
- `payload.decision=rejected`

`override`
- appends `ApprovalRecorded`
- `payload.subject.subject_type=override`
- `payload.subject.subject_id={workflow_id}`
- `payload.decision=approved`

`start_review`
- appends `WorkflowReviewRequested`
- creates a deterministic trace review workflow id:
  `{trace_id}:trace_review:{template_id}`
- carries template, assignee, priority, SLA, and dry-run context into the workflow runtime

`request_change`, `reassign`, `comment`, `escalate`
- do not append decision-domain approval events in v1
- are persisted to `dg_workflow_actions`
- can emit durable workflow notifications

## SLA And Notification Behavior

- overdue open items are automatically escalated during workflow runtime refresh
- escalation transitions also record a durable `escalation` action and notification
- `assignment`, `deadline_risk`, `approval`, `escalation`, and `failure` notifications are deduped per workflow scenario

## Permission Gates

`workflow_review`
- approve
- reject
- request-change
- comment

`workflow_assign`
- reassign
- start trace review / incident review

`workflow_escalate`
- manual escalate

`workflow_override`
- override

`workflow_export`
- export workflow audit payloads

## Required Inputs

Reason required:
- approve
- reject
- request-change
- escalate
- override
- start_review

Assignment target required:
- `reassign` needs `assigned_account_id` or `assigned_role`

Override confirmation required:
- confirmation phrase must equal `OVERRIDE {WORKFLOW_ID_UPPERCASE}`
