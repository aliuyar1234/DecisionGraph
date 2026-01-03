# API Contract: EventStore Protocol

**SSOT Reference**: Section 11.6

## Protocol Definition

```python
class EventStore(Protocol):
    def append_event(self, envelope: EventEnvelope) -> StoredEvent: ...
    def get_trace_events(
        self,
        trace_id: str,
        since_trace_seq: int | None = None,
        limit: int | None = None
    ) -> list[StoredEvent]: ...
    def list_events(
        self,
        since_log_seq: int | None = None,
        until_log_seq: int | None = None,
        event_type: str | None = None,
        limit: int | None = None
    ) -> list[StoredEvent]: ...
    def get_last_log_seq(self) -> int: ...
```

## append_event

Append an event to the log.

**Input**: `EventEnvelope`
**Output**: `StoredEvent` (with `log_seq` and `recorded_at` set)

**Behavior**:
| Scenario | Result |
|----------|--------|
| Valid new event | Store, return StoredEvent |
| Idempotent duplicate | Return original StoredEvent |
| Same key, different payload | Raise `DG_ERR_IDEMPOTENCY_CONFLICT` |
| Trace already finished | Raise `DG_ERR_EVENT_SEQUENCE_INVALID` |
| Wrong trace_seq | Raise `DG_ERR_EVENT_SEQUENCE_INVALID` |
| PII detected | Raise `DG_ERR_PII_POLICY_VIOLATION` |
| Float in payload | Raise `DG_ERR_SCHEMA_VIOLATION` |

**Idempotency Scope**: `(producer_id, idempotency_key)`

## get_trace_events

Get events for a specific trace.

**Input**:
- `trace_id`: UUID string (required)
- `since_trace_seq`: Start from this trace_seq (optional)
- `limit`: Max events to return (optional, default no limit)

**Output**: `list[StoredEvent]` ordered by `trace_seq` ascending

**Errors**:
- `DG_ERR_NOT_FOUND` if trace_id doesn't exist
- `DG_ERR_INVALID_ARGUMENT` if limit > 10000

## list_events

List events from the global log.

**Input**:
- `since_log_seq`: Start from this log_seq (optional)
- `until_log_seq`: End at this log_seq (optional)
- `event_type`: Filter by event type (optional)
- `limit`: Max events to return (optional, default no limit)

**Output**: `list[StoredEvent]` ordered by `log_seq` ascending

**Errors**:
- `DG_ERR_INVALID_ARGUMENT` if since_log_seq > until_log_seq
- `DG_ERR_INVALID_ARGUMENT` if limit > 10000

## get_last_log_seq

Get the current maximum log_seq.

**Output**: `int` (0 if store is empty)

## Ordering Guarantees

1. `log_seq` is globally monotonic (assigned by backend)
2. `trace_seq` is monotonic within a trace
3. `get_trace_events` returns in `trace_seq` order
4. `list_events` returns in `log_seq` order

## Implementation Requirements

1. `log_seq` MUST be assigned atomically at commit time
2. `recorded_at` MUST be set by backend (not trusted from input)
3. Idempotency check MUST happen before any side effects
4. PII guard MUST run before storage
5. trace_seq validation MUST check:
   - TraceStarted has trace_seq=0
   - Each subsequent event is previous + 1
   - No events after TraceFinished
