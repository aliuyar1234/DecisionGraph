# Quickstart: Event Model & Serialization

## Prerequisites

- 001-foundation completed and installed

## Canonical JSON

```python
from decisiongraph.serialization.canonical_json import canonicalize_json

# Keys are sorted, no whitespace
data = {"z": 1, "a": "hello"}
canonical = canonicalize_json(data)
print(canonical)  # '{"a":"hello","z":1}'

# Floats are rejected
try:
    canonicalize_json({"price": 19.99})
except DecisionGraphError as e:
    print(e.code)  # DG_ERR_SCHEMA_VIOLATION
```

## Hashing

```python
from decisiongraph.serialization.hashing import sha256_prefixed

data = b'{"a":"hello","z":1}'
hash_value = sha256_prefixed(data)
print(hash_value)  # sha256:44136fa355b3...
```

## Creating Events

```python
from decisiongraph.domain.events import EventEnvelope
from decisiongraph.domain.types import ActorRef, SourceRef, EntityRef

# Create event envelope
envelope = EventEnvelope(
    event_id="550e8400-e29b-41d4-a716-446655440000",
    trace_id="b3b0a4a8-2a2f-4bdf-b9ce-6a4bbf3aa2c4",
    trace_seq=0,
    event_type="TraceStarted",
    occurred_at="2025-12-31T10:00:00Z",
    recorded_at=None,  # Backend sets this
    source=SourceRef(
        producer_id="renewal-agent-service",
        system="agent-orchestrator"
    ),
    actor=ActorRef(actor_type="agent", actor_id="renewal-agent-v1"),
    correlation_id=None,
    causation_event_id=None,
    idempotency_key="trace-start:b3b0a4a8",
    schema_version=1,
    payload={
        "workflow": "renewal_discount",
        "title": "20% discount for Acme Corp",
        "primary_entity": {
            "entity_type": "Account",
            "entity_id": "ACC-123"
        }
    },
    payload_hash="sha256:...",
    tags={}
)
```

## Using InMemoryEventStore

```python
from decisiongraph.testing.fakes import InMemoryEventStore

store = InMemoryEventStore()

# Append event
stored = store.append_event(envelope)
print(f"log_seq: {stored.log_seq}")
print(f"recorded_at: {stored.recorded_at}")

# Query by trace
events = store.get_trace_events("b3b0a4a8-2a2f-4bdf-b9ce-6a4bbf3aa2c4")
for e in events:
    print(f"{e.trace_seq}: {e.event_type}")

# Idempotent retry - returns same event
stored2 = store.append_event(envelope)
assert stored.log_seq == stored2.log_seq
```

## PII Guard

```python
# These payloads will be rejected
bad_payloads = [
    {"token": "Bearer eyJhbGc..."},
    {"slack_token": "xoxb-12345"},
    {"key": "-----BEGIN RSA PRIVATE KEY-----"},
]

for payload in bad_payloads:
    try:
        # Validation happens before storage
        validate_payload(payload)
    except DecisionGraphError as e:
        print(f"{e.code}: Forbidden content detected")
```

## Running Tests

```bash
# Run event model tests
pytest tests/unit/test_canonical_json.py
pytest tests/unit/test_event_model.py
pytest tests/unit/test_inmemory_store.py
pytest tests/unit/test_pii_guard.py
```

## Next Steps

After this phase, proceed to `003-storage-sqlite` for:
- Persistent storage with SQLite
- Database migrations
- Constraint enforcement
