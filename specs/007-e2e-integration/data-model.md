# Data Model: E2E Integration & Documentation

**Date**: 2026-01-01
**Phase**: P6 — E2E Fixtures + Documentation + Optional CLI
**SSOT Reference**: Section 10

## Golden Fixture Schema

### Fixture File Structure

```
tests/golden/<scenario>/
├── events.json          # Event list
└── expected_digest.txt  # Expected digest
```

### events.json Format

```json
{
  "scenario": "renewal",
  "ssot_reference": "10.1",
  "description": "Renewal Agent with 20% discount exception",
  "trace_id": "b3b0a4a8-2a2f-4bdf-b9ce-6a4bbf3aa2c4",
  "events": [
    {
      "event_id": "uuid-1",
      "trace_id": "b3b0a4a8-2a2f-4bdf-b9ce-6a4bbf3aa2c4",
      "trace_seq": 0,
      "event_type": "TraceStarted",
      "occurred_at": "2025-12-31T10:00:00Z",
      "source": {
        "producer_id": "renewal-agent-service",
        "system": "agent-orchestrator"
      },
      "actor": {
        "actor_type": "agent",
        "actor_id": "renewal-agent-v1"
      },
      "idempotency_key": "trace-start:b3b0a4a8",
      "schema_version": 1,
      "payload": {
        "workflow": "renewal_discount",
        "title": "20% discount for Acme Corp",
        "primary_entity": {
          "entity_type": "Account",
          "entity_id": "ACC-ACME"
        }
      }
    }
  ]
}
```

### expected_digest.txt Format

```
context_graph:sha256:abc123...
precedent_index:sha256:def456...
```

## Golden Fixture Utilities

### GoldenFixture

```python
@dataclass
class GoldenFixture:
    scenario: str
    ssot_reference: str
    description: str
    trace_id: str
    events: list[EventEnvelope]
    expected_digests: dict[str, str]
```

### load_fixture

```python
def load_fixture(path: Path) -> GoldenFixture:
    """Load fixture from JSON file."""
    with open(path / "events.json") as f:
        data = json.load(f)

    events = [envelope_from_dict(e) for e in data["events"]]

    digests = {}
    with open(path / "expected_digest.txt") as f:
        for line in f:
            key, value = line.strip().split(":")
            digests[key] = value

    return GoldenFixture(
        scenario=data["scenario"],
        ssot_reference=data["ssot_reference"],
        description=data["description"],
        trace_id=data["trace_id"],
        events=events,
        expected_digests=digests
    )
```

### replay_fixture

```python
def replay_fixture(store: EventStore, fixture: GoldenFixture) -> dict[str, str]:
    """Replay fixture events and compute digests."""
    for envelope in fixture.events:
        store.append_event(envelope)

    projector = Projector(store)
    projector.rebuild()

    return {
        "context_graph": projector.compute_digest("context_graph"),
        "precedent_index": projector.compute_digest("precedent_index")
    }
```

### validate_fixture

```python
def validate_fixture(path: Path) -> bool:
    """Validate fixture digests match expected."""
    fixture = load_fixture(path)
    store = InMemoryEventStore()
    actual = replay_fixture(store, fixture)

    for key, expected in fixture.expected_digests.items():
        if actual[key] != expected:
            return False
    return True
```

## CLI Interface

### __main__.py

```python
"""
DecisionGraph CLI - Read-only inspection tools.

Usage:
    python -m decisiongraph replay <db>
    python -m decisiongraph dump-trace <db> <trace_id>
"""

import argparse
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(description="DecisionGraph CLI")
    subparsers = parser.add_subparsers(dest="command")

    # replay command
    replay = subparsers.add_parser("replay", help="Rebuild projections")
    replay.add_argument("db", help="Database path")

    # dump-trace command
    dump = subparsers.add_parser("dump-trace", help="Dump trace events")
    dump.add_argument("db", help="Database path")
    dump.add_argument("trace_id", help="Trace ID")

    args = parser.parse_args()

    if args.command == "replay":
        cmd_replay(args.db)
    elif args.command == "dump-trace":
        cmd_dump_trace(args.db, args.trace_id)
```

## Scenarios Summary

| Scenario | Events | Key Features |
|----------|--------|--------------|
| Renewal | 9 | Exception + Approval + PrecedentCited |
| Support | 7 | Cross-system synthesis |
| Deal Desk | 8 | Tribal knowledge + Precedent |
