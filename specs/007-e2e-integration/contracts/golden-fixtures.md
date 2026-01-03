# API Contract: Golden Fixtures

**SSOT Reference**: Section 10

## Fixture Format

### events.json

```json
{
  "scenario": "string",
  "ssot_reference": "10.X",
  "description": "string",
  "trace_id": "uuid",
  "events": [
    {
      "event_id": "uuid",
      "trace_id": "uuid",
      "trace_seq": 0,
      "event_type": "TraceStarted",
      "occurred_at": "RFC3339",
      "source": {
        "producer_id": "string",
        "system": "string",
        "subsystem": "string|null"
      },
      "actor": {
        "actor_type": "agent|person|role|system",
        "actor_id": "string"
      },
      "correlation_id": "uuid|null",
      "causation_event_id": "uuid|null",
      "idempotency_key": "string",
      "schema_version": 1,
      "payload": {},
      "tags": {}
    }
  ]
}
```

### expected_digest.txt

```
context_graph:sha256:<64-char-hex>
precedent_index:sha256:<64-char-hex>
```

## Fixture API

### load_fixture

```python
def load_fixture(path: Path) -> GoldenFixture:
    """
    Load fixture from directory.

    Args:
        path: Directory containing events.json and expected_digest.txt

    Returns:
        GoldenFixture with events and expected digests
    """
```

### replay_fixture

```python
def replay_fixture(store: EventStore, fixture: GoldenFixture) -> dict[str, str]:
    """
    Replay fixture and compute digests.

    Args:
        store: EventStore to replay into
        fixture: Loaded fixture

    Returns:
        Dict mapping projection name to computed digest
    """
```

### validate_fixture

```python
def validate_fixture(path: Path) -> bool:
    """
    Validate fixture digests match.

    Args:
        path: Fixture directory

    Returns:
        True if all digests match expected
    """
```

### check_no_cot

```python
def check_no_cot(fixture: GoldenFixture) -> bool:
    """
    Check fixture contains no Chain-of-Thought content.

    Forbidden patterns:
    - "Bearer "
    - "xoxb-"
    - "xoxp-"
    - "-----BEGIN"

    Returns:
        True if clean, False if forbidden content found
    """
```

## CLI Contract

### replay

```bash
python -m decisiongraph replay <db>
```

**Output**:
```
Replaying N events...
Context Graph Digest: sha256:...
Precedent Index Digest: sha256:...
```

**Exit codes**:
- 0: Success
- 1: Error (database not found, etc.)

### dump-trace

```bash
python -m decisiongraph dump-trace <db> <trace_id>
```

**Output**:
```
Trace: <trace_id>
Workflow: <workflow>
Title: <title>
Status: <outcome or "running">

Events:
  0: TraceStarted @ 2025-12-31T10:00:00Z
  1: EntityObserved @ 2025-12-31T10:00:01Z
  ...
```

**Exit codes**:
- 0: Success
- 1: Trace not found
- 2: Database error

## Scenarios

### Renewal (SSOT 10.1)

| trace_seq | event_type | Key Data |
|-----------|------------|----------|
| 0 | TraceStarted | workflow: renewal_discount |
| 1 | EntityObserved | Account:ACC-ACME |
| 2 | InputObserved | sf_renewal_data |
| 3 | PolicyEvaluated | require_exception |
| 4 | PrecedentCited | previous similar |
| 5 | ExceptionRequested | EXC-001 |
| 6 | ApprovalRecorded | approved by jane.doe |
| 7 | ActionCommitted | OPP-123456 |
| 8 | TraceFinished | success |

### Support (SSOT 10.2)

Cross-system synthesis → Tier 3 escalation

### Deal Desk (SSOT 10.3)

Healthcare extra discount with tribal knowledge
