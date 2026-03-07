# Workflow Retention And Redaction

## Scope

Phase 7 workflow artifacts now include:
- workflow items
- workflow actions
- workflow notifications
- evidence metadata and locators embedded in workflow payloads

## Retention Rules

Default posture for v1:
- workflow items are retained with the related tenant dataset
- workflow actions are retained as the operational audit trail
- workflow notifications are retained because they explain assignment, risk, and escalation posture
- evidence content should be referenced by locator or compact metadata rather than copied inline when avoidable

## Redaction Rules

Operator-facing workflow metadata should prefer:
- ids
- locator references
- policy codes
- short rationales

Avoid embedding:
- raw customer secrets
- credentials
- large free-form evidence blobs
- documents that require their own lifecycle controls

If sensitive payload material must be handled, the preferred v1 pattern is:
1. store it in the source-of-truth system with its own retention controls
2. place only a locator or evidence reference in workflow metadata
3. keep exports limited to the locator, rationale, and audit context

## Export Implications

Workflow exports are audit-focused, not full evidence dumps.

Exports should remain safe to share internally by default:
- include workflow state, actions, notifications, trace references, and rationale
- avoid embedding evidence bodies when a locator will do

## Known Limit

Phase 7 does not yet implement per-field redaction policies or multiple export classes.
