# Approval And Override Policy

## Intent

Approvals, escalations, and overrides must be easier to audit than to misuse.

## Review And Assignment Policy

Standard review actions:
- approve
- reject
- request-change
- comment
- reassign
- escalate

Standard requirements:
- tenant-scoped authenticated service account
- `workflow_review` for approve/reject/request-change/comment
- `workflow_assign` for reassign and starting trace review workflows
- `workflow_escalate` for manual escalation
- non-empty rationale for approve/reject/request-change/escalate

Review outcomes are reflected in:
- `dg_workflow_actions`
- `ApprovalRecorded` events for approval decisions
- `dg_workflow_notifications` for assignment, approval, risk, escalation, and failure signals

## Override Policy

Overrides are intentionally harder than ordinary approvals.

Override requirements:
- tenant-scoped authenticated service account
- `workflow_override` permission
- explicit rationale
- typed confirmation phrase: `OVERRIDE {WORKFLOW_ID_UPPERCASE}`

Override audit capture:
- workflow action audit log via `api_workflow_override_*`
- persisted workflow action row in `dg_workflow_actions`
- `ApprovalRecorded` event with `subject_type=override`

## Export Policy

Workflow audit exports require:
- tenant-scoped authenticated service account
- `workflow_export` permission

Exports include:
- workflow item snapshot
- workflow actions
- workflow notifications
- trace reference
- audit summary metadata

## Safety Notes

- escalation is separated from ordinary review via `workflow_escalate`
- trace-review creation is separated from ordinary approval via `workflow_assign`
- deadline-risk and failure notifications stay operator-visible even when no approval has closed the workflow

## Current Limits

Current v1 does not yet include:
- dual control or multi-reviewer quorum
- external ticketing handoff enforcement
- evidence blob retention outside metadata capture
- redaction-specific export variants beyond metadata discipline
