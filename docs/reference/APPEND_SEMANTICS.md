# Append Semantics

This document freezes the observable write-path behavior of the Python reference implementation.

## Append Pipeline

For every incoming `EventEnvelope`, the reference implementation does the following in order:

1. validate the idempotency key
2. validate payload JSON safety
3. validate payload shape for the chosen event type
4. scan payload and selected metadata through the PII guard
5. compute canonical payload hash
6. serialize payload and tags to JSON
7. compute `recorded_at`
8. enforce idempotency semantics
9. enforce trace sequencing semantics
10. enforce `TraceFinished` locking
11. persist and return `StoredEvent`

## Idempotency

Idempotent reuse is scoped by the backend-specific uniqueness rule and then validated against the stored event.

The reference behavior requires:

- payload hash must match exactly
- `trace_id` must match
- `event_type` must match
- `source` must match
- `actor` must match
- `correlation_id` must match
- `causation_event_id` must match
- `schema_version` must match
- `tags` must match

`trace_seq` is intentionally excluded from idempotent-reuse matching. This is a frozen behavior and future ports must preserve it.

## Trace Sequencing

- the next event for a trace must use the exact next `trace_seq`
- `TraceStarted` must use `trace_seq = 0`
- no non-`TraceStarted` event may use `trace_seq = 0`

These rules are part of the append contract, not merely a projector concern.

## TraceFinished Lock

Once a trace contains `TraceFinished`, later appends to that trace must be rejected.

This lock is part of the semantic contract for all backends.

## Hash and Timestamp Semantics

- `payload_hash` is computed from canonical payload JSON only
- `occurred_at` comes from the caller and is part of the semantic event record
- `recorded_at` is storage-time metadata and is not part of deterministic digest comparison

## Error Semantics

Backends may differ in implementation details, but they must preserve the same behavior categories:

- invalid arguments
- schema violations
- PII-policy violations
- idempotency conflicts
- sequence errors
- storage conflicts such as post-finish writes

Exact human-readable error text may evolve, but the observable failure mode must not.
