# Payload Shape Matrix

This matrix freezes the intended payload contract for the current event vocabulary.

The Python runtime enforces the required keys and basic container types listed here. Literal domains and some deeper semantic expectations are normative even where the current validation layer is lighter.

| Event Type | Required Keys | Optional Keys | Notes |
| --- | --- | --- | --- |
| `TraceStarted` | `workflow`, `title`, `primary_entity.entity_type`, `primary_entity.entity_id` | `primary_entity.system`, `context` | `trace_seq` must be `0` |
| `InputObserved` | `input_id`, `source.system`, `source.object_type`, `source.object_id`, `facts` | `source.locator` | Facts must remain JSON-safe and string-valued per `Value` |
| `EntityObserved` | `entity.entity_type`, `entity.entity_id`, `role`, `facts` | `entity.system` | `role` is normatively `primary` or `related` |
| `PolicyEvaluated` | `policy.policy_id`, `policy.policy_version`, `inputs`, `decision` | `violations`, `explanation` | `decision` is normatively `allow`, `deny`, or `require_exception` |
| `ExceptionRequested` | `exception_id`, `policy.policy_id`, `policy.policy_version`, `reason` | `evidence` | Evidence references are optional |
| `ApprovalRecorded` | `approval_id`, `subject.subject_type`, `subject.subject_id`, `approver.actor_type`, `approver.actor_id`, `decision` | `reason`, `evidence`, extra subject metadata | `decision` is normatively `approved` or `rejected` |
| `PrecedentCited` | `cited_trace_id`, `reason` | `similarity_score` | `similarity_score` stays string-based; no floats |
| `ActionProposed` | `action_id`, `action_type`, `target_entity.entity_type`, `target_entity.entity_id`, `target_system`, `changes` | `target_entity.system` | `changes` hold string-encoded typed values |
| `ActionCommitted` | `action_id`, `status` | `external_reference`, `error` | `status` is normatively `success`, `failure`, or `partial` |
| `TraceFinished` | `outcome` | `summary` | `outcome` is normatively `success`, `failure`, or `abandoned` |

## Payload-Wide Rules

- Payloads must be JSON-serializable.
- Payloads must not contain forbidden PII or secret substrings.
- Canonicalization forbids floats in the deterministic payload-hash path.
- Ports must preserve canonical payload equivalence, not just shape equivalence.
