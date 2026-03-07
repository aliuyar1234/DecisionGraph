# Workflow Runtime

## Runtime Shape

The Phase 7 workflow layer is a tenant-scoped operational runtime derived from the decision event log plus workflow-side operational records.

Core tables:
- `dg_workflow_runtime`
- `dg_workflow_items`
- `dg_workflow_actions`
- `dg_workflow_notifications`

The workflow runtime cursor tracks the highest processed `dg_event_log.log_seq` per tenant.

## Event Inputs

The runtime now processes:
- `ExceptionRequested`
- `ApprovalRecorded`
- `WorkflowReviewRequested`

`WorkflowReviewRequested` is the trace-to-review bridge used by the workflow studio and incident-review console flow.

## Refresh Model

Workflow refresh happens when these surfaces are used:
- workflow inbox reads
- workflow detail reads
- workflow actions
- workflow exports
- workflow studio reads and creates
- operator console snapshot loads

Each refresh:
1. advances the workflow cursor from `dg_event_log`
2. applies new source events to workflow items and source actions
3. runs SLA sweeps for deadline risk and automatic escalation
4. emits deduped operator-console notifications

## API Surfaces

Read:
- `GET /api/v1/workflows`
- `GET /api/v1/workflows/:workflow_id`
- `GET /api/v1/workflow-studio/templates`
- `GET /api/v1/workflow-studio/traces/:trace_id`

Write:
- `POST /api/v1/workflows/:workflow_id/actions`
- `POST /api/v1/workflow-studio/traces/:trace_id/reviews`

Audit export:
- `GET /api/v1/admin/workflows/:workflow_id/export`

## SLA And Escalation Rules

- standard exception reviews receive `exception_review_sla_hours`
- trace-review workflows receive `incident_review_sla_hours` or the template SLA
- items nearing deadline emit `deadline_risk` notifications
- overdue open items are automatically moved to `escalated`
- escalated items inherit `escalation_assigned_role` / `escalation_assigned_account_id` when configured

## Notification Model

Current v1 delivery is intentionally narrow and durable:
- channel: `operator_console`
- categories: `assignment`, `approval`, `deadline_risk`, `escalation`, `failure`
- dedupe is enforced by `(tenant_id, dedupe_key)`

## Operator Guidance

If a workflow item appears stale:
1. confirm the tenant id
2. refresh the operator console or query the inbox again
3. verify the related source event exists in `dg_event_log`
4. confirm the workflow runtime cursor advanced for that tenant

If an action is rejected:
1. verify the service account has the required workflow permission
2. verify the workflow is not already terminal
3. for overrides, verify the typed confirmation phrase exactly matches the required value
4. check workflow notifications for any recorded `failure` signal

If an item should have escalated but did not:
1. confirm `sla_due_at` is populated
2. confirm the item is still in an open state
3. refresh a workflow or console read to force the runtime sweep
4. inspect `dg_workflow_notifications` for `deadline_risk` and `escalation` entries

## Current Known Limits

Current v1 behavior is intentionally bounded:
- workflow sync is still pull-on-read rather than a dedicated projector partition
- notifications stay inside the operator console; there is no email, Slack, or pager delivery yet
- evidence is metadata or locator-based, not blob storage
- incident-review templates are intentionally small and curated rather than user-authored
