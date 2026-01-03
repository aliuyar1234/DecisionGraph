# Data Model: DecisionGraph Foundation

**Date**: 2026-01-01
**Phase**: P0 — Repo Bootstrap + Contracts
**SSOT Reference**: Section 11.2

## Domain Types

All types are stdlib `dataclasses` per DD-004.

### ActorRef

Represents an actor (agent, person, role, system).

```python
@dataclass(frozen=True)
class ActorRef:
    actor_type: Literal["agent", "person", "role", "system"]
    actor_id: str
```

**Validation**:
- `actor_type` must be one of the literal values
- `actor_id` must be non-empty string

### EntityRef

Represents a business entity (Account, Ticket, etc.).

```python
@dataclass(frozen=True)
class EntityRef:
    entity_type: str
    entity_id: str
    system: str | None = None
```

**Validation**:
- `entity_type` and `entity_id` must be non-empty strings

### Value

Typed value with string representation (no floats per DD-008).

```python
@dataclass(frozen=True)
class Value:
    type: Literal["string", "int", "bool", "decimal", "date", "datetime", "json"]
    value: str
```

**Validation**:
- `type` must be one of the literal values
- `value` is always stored as string (decimals as "123.45", not float)

### Fact

Key-value pair with optional as_of timestamp.

```python
@dataclass(frozen=True)
class Fact:
    key: str
    value: Value
    as_of: str | None = None  # RFC3339
```

### SourceRef

Reference to source system (producer identification).

```python
@dataclass(frozen=True)
class SourceRef:
    producer_id: str
    system: str
    subsystem: str | None = None
```

### SourceObjectRef

Reference to source system object.

```python
@dataclass(frozen=True)
class SourceObjectRef:
    system: str
    object_type: str
    object_id: str
    locator: str | None = None
```

### EvidenceRef

Reference to evidence with optional redacted excerpt.

```python
@dataclass(frozen=True)
class EvidenceRef:
    source: SourceObjectRef
    locator: str
    excerpt_redacted: str | None = None
```

### PolicyRef

Reference to a policy.

```python
@dataclass(frozen=True)
class PolicyRef:
    policy_id: str
    policy_version: str
```

### Violation

Policy violation with code and details.

```python
@dataclass(frozen=True)
class Violation:
    code: str
    message: str
    details: dict[str, str] | None = None
```

### Change

Field change with path and value.

```python
@dataclass(frozen=True)
class Change:
    path: str
    old_value: Value | None
    new_value: Value
```

### ApprovalSubject

Subject of approval (exception or action).

```python
@dataclass(frozen=True)
class ApprovalSubject:
    subject_type: Literal["exception", "action"]
    subject_id: str
```

## Error Types

### DecisionGraphError

Base exception for all DecisionGraph errors.

```python
class DecisionGraphError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(f"{code}: {message}")
```

**Error Codes** (SSOT 7.2):
- `DG_ERR_NOT_FOUND`
- `DG_ERR_CONFLICT`
- `DG_ERR_IDEMPOTENCY_CONFLICT`
- `DG_ERR_SCHEMA_VIOLATION`
- `DG_ERR_EVENT_SEQUENCE_INVALID`
- `DG_ERR_PROJECTION_OUT_OF_DATE`
- `DG_ERR_INVALID_ARGUMENT`
- `DG_ERR_STORAGE`
- `DG_ERR_PII_POLICY_VIOLATION`

## Relationships

```
ActorRef ──────────────────────────┐
                                   │
EntityRef ─────────────────────────┼──→ Used in Event Payloads
                                   │
PolicyRef ─────────────────────────┘

SourceRef ────→ Event.source

Value ────→ Fact.value
      ────→ Change.old_value / new_value

SourceObjectRef ────→ EvidenceRef.source

ApprovalSubject ────→ ApprovalRecorded payload
```

## Immutability

All domain types use `frozen=True` to enforce immutability per Constitution I (Append-Only SSOT).
