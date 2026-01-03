# Data Model: Event Model & Serialization

**Date**: 2026-01-01
**Phase**: P1 — Event Model + Canonical Serialization + InMemory Store
**SSOT Reference**: Sections 6.1, 11.3, 11.6

## Event Envelope

The event envelope contains all metadata for an event.

```python
@dataclass
class EventEnvelope:
    event_id: str              # UUID
    trace_id: str              # UUID
    trace_seq: int             # 0-based, monotonic within trace
    event_type: str            # One of 10 types
    occurred_at: str           # RFC3339 UTC
    recorded_at: str | None    # Set by backend, null in input
    source: SourceRef          # Producer identification
    actor: ActorRef            # Who performed action
    correlation_id: str | None # Optional correlation
    causation_event_id: str | None
    idempotency_key: str       # Unique per (producer_id, key)
    schema_version: int        # Always 1 for now
    payload: dict              # Event-type-specific
    payload_hash: str          # sha256:<hex>
    tags: dict[str, str]       # Optional key-value tags
```

## Stored Event

After persistence, event has log_seq and recorded_at.

```python
@dataclass(frozen=True)
class StoredEvent:
    log_seq: int               # Global ordering, assigned by backend
    event_id: str
    trace_id: str
    trace_seq: int
    event_type: str
    occurred_at: str
    recorded_at: str           # Always set (by backend)
    source: SourceRef
    actor: ActorRef
    correlation_id: str | None
    causation_event_id: str | None
    idempotency_key: str
    schema_version: int
    payload: dict
    payload_hash: str
    tags: dict[str, str]
```

## Event Types and Payloads

### TraceStarted (trace_seq = 0)

```python
@dataclass
class TraceStartedPayload:
    workflow: str
    title: str
    primary_entity: EntityRef
    context: dict[str, str] | None = None
```

### InputObserved

```python
@dataclass
class InputObservedPayload:
    input_id: str
    source: SourceObjectRef
    facts: list[Fact]
```

### EntityObserved

```python
@dataclass
class EntityObservedPayload:
    entity: EntityRef
    role: Literal["primary", "related"]
    facts: list[Fact]
```

### PolicyEvaluated

```python
@dataclass
class PolicyEvaluatedPayload:
    policy: PolicyRef
    inputs: list[str]  # input_ids
    decision: Literal["allow", "deny", "require_exception"]
    violations: list[Violation] | None = None
    explanation: dict | None = None
```

### ExceptionRequested

```python
@dataclass
class ExceptionRequestedPayload:
    exception_id: str
    policy: PolicyRef
    reason: str
    evidence: list[EvidenceRef] | None = None
```

### ApprovalRecorded

```python
@dataclass
class ApprovalRecordedPayload:
    approval_id: str
    subject: ApprovalSubject
    approver: ActorRef
    decision: Literal["approved", "rejected"]
    reason: str | None = None
    evidence: list[EvidenceRef] | None = None
```

### PrecedentCited

```python
@dataclass
class PrecedentCitedPayload:
    cited_trace_id: str
    reason: str
    similarity_score: str | None = None  # Decimal as string
```

### ActionProposed

```python
@dataclass
class ActionProposedPayload:
    action_id: str
    action_type: str
    target_entity: EntityRef
    target_system: str
    changes: list[Change]
```

### ActionCommitted

```python
@dataclass
class ActionCommittedPayload:
    action_id: str
    status: Literal["success", "failure", "partial"]
    external_reference: str | None = None
    error: str | None = None
```

### TraceFinished

```python
@dataclass
class TraceFinishedPayload:
    outcome: Literal["success", "failure", "abandoned"]
    summary: str | None = None
```

## EventStore Protocol

```python
class EventStore(Protocol):
    def append_event(self, envelope: EventEnvelope) -> StoredEvent:
        """Append event, return stored event with log_seq."""
        ...

    def get_trace_events(
        self,
        trace_id: str,
        since_trace_seq: int | None = None,
        limit: int | None = None
    ) -> list[StoredEvent]:
        """Get events for trace, ordered by trace_seq."""
        ...

    def list_events(
        self,
        since_log_seq: int | None = None,
        until_log_seq: int | None = None,
        event_type: str | None = None,
        limit: int | None = None
    ) -> list[StoredEvent]:
        """List events, ordered by log_seq."""
        ...

    def get_last_log_seq(self) -> int:
        """Get current max log_seq (0 if empty)."""
        ...
```

## State Transitions

```
[New Trace]
    │
    ▼
TraceStarted (trace_seq=0)
    │
    ▼
┌─────────────────────────────────────┐
│  Any of:                            │
│  - InputObserved                    │
│  - EntityObserved                   │
│  - PolicyEvaluated                  │
│  - ExceptionRequested               │
│  - ApprovalRecorded                 │
│  - PrecedentCited                   │
│  - ActionProposed                   │
│  - ActionCommitted                  │
│  (trace_seq increments by 1 each)   │
└─────────────────────────────────────┘
    │
    ▼
TraceFinished (locks trace)
    │
    ▼
[No more events allowed]
```
