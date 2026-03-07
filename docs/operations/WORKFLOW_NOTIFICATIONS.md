# Workflow Notifications

## V1 Notification Channels

Current Phase 7 delivery is intentionally narrow:
- operator console notification history on each workflow
- operator console alert banners
- workflow inbox ordering and overdue counts

There is still no external email, Slack, pager, or ticketing delivery in this slice.

## Durable Notification Categories

The runtime persists these operator-facing categories in `dg_workflow_notifications`:
- `assignment`
- `approval`
- `deadline_risk`
- `escalation`
- `failure`

Each notification is deduped by `(tenant_id, dedupe_key)` so repeated reads do not create alert spam.

## What Triggers A Notification

`assignment`
- imported exception review creation
- workflow studio trace-review creation
- manual reassignment

`approval`
- `ApprovalRecorded` source events

`deadline_risk`
- open items approaching their SLA deadline within the configured warning window

`escalation`
- automatic SLA escalation
- manual escalation actions

`failure`
- failed workflow-side attempts to append required decision events

## Why The Scope Is Small

Phase 7 prioritizes trustworthy workflow state, audit capture, and operator usability before broad channel fan-out.

Before external delivery is added, the platform now already proves:
- assignment and escalation state are queryable
- workflow notifications are durable and export-adjacent
- alerting is deduped rather than noisy

## Operational Notes

- notification reads are tenant-scoped
- notification history is surfaced inside workflow detail
- alert banners remain summary-level while workflow detail holds the durable record
