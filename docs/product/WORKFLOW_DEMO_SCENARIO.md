# Workflow Demo Scenario

## Goal

Show a full Phase 7 operator journey without leaving the DecisionGraph console.

## Scenario

1. A trace enters the system and evaluates policy for a customer deal.
2. The policy run raises `ExceptionRequested`.
3. The workflow inbox shows the new exception review with assignment and SLA.
4. The operator opens the workflow detail and sees:
   - action history
   - notification history
   - precedent preview
   - replay suggestion
5. The item approaches its SLA window and emits a `deadline_risk` notification.
6. If the item remains open past SLA, it auto-escalates and the assignee shifts to the escalation role.
7. The operator opens the workflow studio from the selected trace and starts an `incident_triage` review.
8. The new `WorkflowReviewRequested` event creates a trace-review workflow item.
9. The operator compares precedents, inspects the trace timeline, and checks the replay suggestion.
10. The operator approves, rejects, or overrides with full audit capture.
11. An admin exports the workflow history and receives item state, actions, notifications, and trace reference in one payload.

## What This Demonstrates

- inbox-driven human review
- deterministic SLA escalation
- durable notification history
- trace-to-review workflow creation
- replay-plus-review incident investigation
- audit-friendly export posture
