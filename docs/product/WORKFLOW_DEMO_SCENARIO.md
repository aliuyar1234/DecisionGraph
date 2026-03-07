# Workflow Demo Scenario

## Goal

Show the Phase 7 workflow layer inside the real Phase 10 self-hosted release demo.

## Scenario

1. Seed the `release-demo` tenant with `mix dg.demo.seed`.
2. Open `trace-live-renewal-002`.
3. The policy run has already raised `ExceptionRequested`.
4. The workflow inbox shows the exception review with assignment, SLA state, and escalation.
5. The operator opens the workflow detail and sees:
   - action history
   - notification history
   - precedent preview
   - replay suggestion
6. In the seeded release demo, the item is already overdue and escalated, so the operator immediately sees a visible `deadline_risk` posture without waiting.
7. The operator opens the workflow studio from the selected trace and reviews the existing `incident_triage` item on `trace-incident-review-003`.
8. The `WorkflowReviewRequested` path has already created a trace-review workflow item:
   - `trace-incident-review-003:trace_review:incident_triage`
9. The operator compares precedents, inspects the trace timeline, and checks the replay suggestion.
10. The operator approves, rejects, reassigns, or overrides with full audit capture.
11. An admin exports the workflow history and receives item state, actions, notifications, and trace reference in one payload.

## What This Demonstrates

- inbox-driven human review
- deterministic SLA escalation
- durable notification history
- trace-to-review workflow creation
- replay-plus-review incident investigation
- audit-friendly export posture
- escalated SLA state visible on first load
