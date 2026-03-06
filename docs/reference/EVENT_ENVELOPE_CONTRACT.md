# Event Envelope Contract

## Status

Frozen as part of the `semantic-reference-python-v1` baseline.

## EventEnvelope Shape

`EventEnvelope` is the pre-storage contract. Every append path produces or accepts this shape before persistence.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `event_id` | `str` | yes | Caller-supplied event identifier |
| `trace_id` | `str` | yes | Trace membership key |
| `trace_seq` | `int` | yes | Per-trace monotonic sequence |
| `event_type` | `str` | yes | Must be one of the frozen event types below |
| `occurred_at` | `str` | yes | RFC3339 timestamp from the event source |
| `source` | object | yes | `producer_id`, `system`, optional `subsystem` |
| `actor` | object | yes | `actor_type`, `actor_id` |
| `idempotency_key` | `str` | yes | Producer-scoped idempotency key |
| `payload` | object | yes | Event-type-specific body |
| `correlation_id` | `str \| null` | no | Optional cross-trace correlation |
| `causation_event_id` | `str \| null` | no | Optional causal link |
| `schema_version` | `int` | no | Defaults to `1` |
| `tags` | `list[str]` | no | Defaults to `[]` |

## StoredEvent Additions

Persistence extends the envelope into `StoredEvent` by adding:

- `log_seq`: globally ordered append sequence
- `recorded_at`: storage-time timestamp
- `payload_hash`: SHA-256 over canonical payload JSON

`recorded_at` is operational metadata. It is intentionally excluded from deterministic digest rules.

## Frozen Event Vocabulary

The current supported event types are:

- `TraceStarted`
- `InputObserved`
- `EntityObserved`
- `PolicyEvaluated`
- `ExceptionRequested`
- `ApprovalRecorded`
- `PrecedentCited`
- `ActionProposed`
- `ActionCommitted`
- `TraceFinished`

Adding, removing, or renaming an event type is a semantic change and must go through the parity review policy.

## Envelope Invariants

- `TraceStarted` is the only valid first event in a trace.
- `trace_seq` starts at `0` and advances by exactly `1`.
- `schema_version` defaults to `1` unless the caller overrides it.
- `payload_hash` is computed only from `payload`, not from the rest of the envelope.
- `source`, `actor`, `tags`, `correlation_id`, and `causation_event_id` participate in idempotent-reuse matching.
- `trace_seq` intentionally does not participate in idempotent-reuse metadata matching.

## Normative vs Runtime-Validated

The reference runtime validates required keys and core structural types. The dataclass definitions and this document are more specific than some of the current runtime checks.

Example:

- `PolicyEvaluated.decision` is documented as `allow | deny | require_exception`
- `ActionCommitted.status` is documented as `success | failure | partial`

A BEAM port must preserve the documented semantic domain, not just the looser current string checks.
