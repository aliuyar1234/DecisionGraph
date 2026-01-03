# Quickstart: SQLite Storage Backend

## Prerequisites

- 001-foundation completed
- 002-event-model completed

## Basic Usage

```python
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.domain.events import EventEnvelope
from decisiongraph.domain.types import ActorRef, SourceRef

# Create store (migrations run automatically)
store = SQLiteEventStore("decisiongraph.db")

# Create an event
envelope = EventEnvelope(
    event_id="550e8400-e29b-41d4-a716-446655440000",
    trace_id="b3b0a4a8-2a2f-4bdf-b9ce-6a4bbf3aa2c4",
    trace_seq=0,
    event_type="TraceStarted",
    occurred_at="2025-12-31T10:00:00Z",
    recorded_at=None,
    source=SourceRef(producer_id="test", system="test"),
    actor=ActorRef(actor_type="agent", actor_id="test-agent"),
    correlation_id=None,
    causation_event_id=None,
    idempotency_key="test:trace:001",
    schema_version=1,
    payload={"workflow": "test", "title": "Test", "primary_entity": {...}},
    payload_hash="sha256:...",
    tags={}
)

# Append event
stored = store.append_event(envelope)
print(f"log_seq: {stored.log_seq}")
print(f"recorded_at: {stored.recorded_at}")
```

## Query Events

```python
# Get all events for a trace
events = store.get_trace_events("b3b0a4a8-2a2f-4bdf-b9ce-6a4bbf3aa2c4")
for e in events:
    print(f"{e.trace_seq}: {e.event_type}")

# List recent events
recent = store.list_events(limit=10)

# Get events by type
policy_evals = store.list_events(event_type="PolicyEvaluated")

# Get current position
last_seq = store.get_last_log_seq()
print(f"Last log_seq: {last_seq}")
```

## Idempotent Retries

```python
# First attempt
stored1 = store.append_event(envelope)

# Retry with same idempotency key - returns same event
stored2 = store.append_event(envelope)
assert stored1.log_seq == stored2.log_seq

# Different payload with same key - raises error
try:
    envelope.payload = {"different": "data"}
    store.append_event(envelope)
except DecisionGraphError as e:
    print(e.code)  # DG_ERR_IDEMPOTENCY_CONFLICT
```

## Constraint Enforcement

```python
# trace_seq must be sequential
# This will fail if trace_seq=1 doesn't exist
envelope.trace_seq = 2
try:
    store.append_event(envelope)
except DecisionGraphError as e:
    print(e.code)  # DG_ERR_EVENT_SEQUENCE_INVALID

# No events after TraceFinished
# Finish the trace
finish_event = EventEnvelope(
    ...,
    event_type="TraceFinished",
    trace_seq=5,
    ...
)
store.append_event(finish_event)

# Now any new event fails
try:
    store.append_event(next_event)
except DecisionGraphError as e:
    print(e.code)  # DG_ERR_EVENT_SEQUENCE_INVALID
```

## Migration Management

```python
# Migrations run automatically on init
store = SQLiteEventStore("new.db")

# Check migration status
import sqlite3
conn = sqlite3.connect("new.db")
cursor = conn.execute("SELECT version FROM schema_migrations ORDER BY version")
for row in cursor:
    print(f"Migration {row[0]} applied")
```

## Running Tests

```bash
# Run SQLite integration tests
pytest tests/integration/test_sqlite_backend.py -v

# Run with temp database
pytest tests/integration/test_sqlite_backend.py --db-path=:memory:
```

## Next Steps

After this phase, proceed to `004-projections` for:
- Projection engine
- Context graph building
- Deterministic digests
