# API Contract: Domain Types

**SSOT Reference**: Section 11.2

## Type Definitions

All types are `@dataclass(frozen=True)` - immutable value objects.

### ActorRef

```python
@dataclass(frozen=True)
class ActorRef:
    actor_type: Literal["agent", "person", "role", "system"]
    actor_id: str
```

**Constraints**:
- `actor_type` MUST be one of: `"agent"`, `"person"`, `"role"`, `"system"`
- `actor_id` MUST be non-empty string

**Usage**:
```python
actor = ActorRef(actor_type="agent", actor_id="renewal-agent-v1")
```

### EntityRef

```python
@dataclass(frozen=True)
class EntityRef:
    entity_type: str
    entity_id: str
    system: str | None = None
```

**Constraints**:
- `entity_type` and `entity_id` MUST be non-empty strings
- `system` is optional, identifies source system

**Usage**:
```python
entity = EntityRef(entity_type="Account", entity_id="ACC-123", system="salesforce")
```

### Value

```python
@dataclass(frozen=True)
class Value:
    type: Literal["string", "int", "bool", "decimal", "date", "datetime", "json"]
    value: str
```

**Constraints**:
- `type` MUST be one of the literal values
- `value` is ALWAYS stored as string (per DD-008, no floats)
- Decimals: `"123.45"` not `123.45`
- Booleans: `"true"` or `"false"`
- Dates: `"2025-12-31"` (ISO 8601)
- Datetimes: `"2025-12-31T10:00:00Z"` (RFC 3339)

**Usage**:
```python
decimal_val = Value(type="decimal", value="123.45")
bool_val = Value(type="bool", value="true")
date_val = Value(type="date", value="2025-12-31")
```

### Fact

```python
@dataclass(frozen=True)
class Fact:
    key: str
    value: Value
    as_of: str | None = None  # RFC3339 timestamp
```

**Usage**:
```python
fact = Fact(
    key="arr_usd",
    value=Value(type="decimal", value="50000.00"),
    as_of="2025-12-31T00:00:00Z"
)
```

### SourceRef

```python
@dataclass(frozen=True)
class SourceRef:
    producer_id: str
    system: str
    subsystem: str | None = None
```

**Constraints**:
- `producer_id` identifies the emitting service/agent
- `system` identifies the system category
- `subsystem` is optional refinement

### SourceObjectRef

```python
@dataclass(frozen=True)
class SourceObjectRef:
    system: str
    object_type: str
    object_id: str
    locator: str | None = None
```

**Usage**:
```python
ref = SourceObjectRef(
    system="salesforce",
    object_type="Opportunity",
    object_id="OPP-456",
    locator="https://salesforce.com/opp/456"
)
```

### EvidenceRef

```python
@dataclass(frozen=True)
class EvidenceRef:
    source: SourceObjectRef
    locator: str
    excerpt_redacted: str | None = None
```

**Constraints**:
- `excerpt_redacted` MUST NOT contain PII/secrets (see PII Guard)

### PolicyRef

```python
@dataclass(frozen=True)
class PolicyRef:
    policy_id: str
    policy_version: str
```

### Violation

```python
@dataclass(frozen=True)
class Violation:
    code: str
    message: str
    details: dict[str, str] | None = None
```

### Change

```python
@dataclass(frozen=True)
class Change:
    path: str
    old_value: Value | None
    new_value: Value
```

### ApprovalSubject

```python
@dataclass(frozen=True)
class ApprovalSubject:
    subject_type: Literal["exception", "action"]
    subject_id: str
```

## Serialization Contract

All types MUST be serializable to canonical JSON (SSOT 6.1.5):
- Keys sorted lexicographically
- No whitespace
- No floats (use string representation)
- UTF-8 encoding
