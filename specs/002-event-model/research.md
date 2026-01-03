# Research: Event Model & Serialization

**Date**: 2026-01-01
**Phase**: P1 — Event Model + Canonical Serialization + InMemory Store

## Overview

All technical decisions are frozen in SSOT. This document consolidates the relevant specifications.

## Canonical JSON Rules (SSOT 6.1.5)

### Serialization Rules

1. **Key Ordering**: Keys MUST be sorted lexicographically (Unicode code points)
2. **Whitespace**: No whitespace between tokens
3. **Numbers**:
   - Integers as-is
   - **NO FLOATS** - decimals MUST be strings ("123.45")
4. **Strings**: UTF-8, escape only required characters
5. **Nulls**: Represented as `null`
6. **Booleans**: `true` or `false` (lowercase)

### Float Rejection

Floats are rejected because:
- IEEE 754 representation varies across platforms
- Serialization can produce different strings (1.0 vs 1.0000000000000001)
- Decimals as strings are deterministic

### Example

Input:
```python
{"z": 1, "a": "hello", "m": {"b": 2, "a": 1}}
```

Canonical output:
```json
{"a":"hello","m":{"a":1,"b":2},"z":1}
```

## Event Types (SSOT 6.1.2)

| # | Event Type | Payload Key Fields |
|---|------------|-------------------|
| 1 | TraceStarted | workflow, title, primary_entity |
| 2 | InputObserved | input_id, source, facts |
| 3 | EntityObserved | entity, role, facts |
| 4 | PolicyEvaluated | policy, inputs, decision, violations |
| 5 | ExceptionRequested | exception_id, policy, reason |
| 6 | ApprovalRecorded | approval_id, subject, approver, decision |
| 7 | PrecedentCited | cited_trace_id, reason |
| 8 | ActionProposed | action_id, action_type, target_entity |
| 9 | ActionCommitted | action_id, status, external_reference |
| 10 | TraceFinished | outcome, summary |

## Idempotency (SSOT 6.1.7)

### Scope

Idempotency is scoped to `(producer_id, idempotency_key)`:
- Different producers with same key = both stored
- Same producer with same key = idempotent (returns original)
- Same producer, same key, different payload = CONFLICT error

### Key Format Recommendation

```
{event_type}:trace={trace_id}:seq={trace_seq}
```

Example: `policy-eval:trace=b3b0...:seq=1`

### Behavior

| Scenario | Result |
|----------|--------|
| First emit | Store, return StoredEvent |
| Exact duplicate | Return original StoredEvent |
| Same key, different payload | DG_ERR_IDEMPOTENCY_CONFLICT |

## PII Guard (SSOT 6.1.8.1)

### Forbidden Substrings

```python
FORBIDDEN_SUBSTRINGS = [
    "Bearer ",
    "xoxb-",
    "xoxp-",
    "-----BEGIN",
]
```

### Scan Scope

- Entire canonical JSON payload
- Recursive through all string values
- Case-sensitive matching

### Behavior

If any forbidden substring found → `DG_ERR_PII_POLICY_VIOLATION`

## Trace Sequence Rules (SSOT 2.1)

1. `trace_seq` starts at 0 with TraceStarted
2. Each subsequent event increments by exactly 1
3. After TraceFinished, no more events accepted
4. Gaps in trace_seq → `DG_ERR_EVENT_SEQUENCE_INVALID`

## StoredEvent vs EventEnvelope (DD-020)

### EventEnvelope (input)

- Has all fields except `log_seq`
- `recorded_at` MAY be null (backend sets it)

### StoredEvent (output)

- Has all fields including `log_seq`
- `recorded_at` is always set by backend

### Return Contract

`EventStore.append_event(envelope) -> StoredEvent`
- Always returns StoredEvent (not just log_seq)
- On idempotent duplicate, returns original StoredEvent

## Conclusion

All technical details are specified in SSOT. No external research required.
