# API Contract: Error Codes

**SSOT Reference**: Section 7.2

## DecisionGraphError

Base exception for all DecisionGraph operations.

### Structure

```python
class DecisionGraphError(Exception):
    code: str      # Error code from defined set
    message: str   # Human-readable message
```

### String Representation

```
{code}: {message}
```

Example: `DG_ERR_NOT_FOUND: Trace b3b0a4a8-... not found`

## Error Codes

| Code | Description | When Raised |
|------|-------------|-------------|
| `DG_ERR_NOT_FOUND` | Resource not found | Query for non-existent trace/event |
| `DG_ERR_CONFLICT` | Conflict with existing state | Hash mismatch on read |
| `DG_ERR_IDEMPOTENCY_CONFLICT` | Idempotency key reused with different payload | Retry with different data |
| `DG_ERR_SCHEMA_VIOLATION` | Payload doesn't match schema | Invalid event payload |
| `DG_ERR_EVENT_SEQUENCE_INVALID` | trace_seq out of order or trace finished | Append after TraceFinished |
| `DG_ERR_PROJECTION_OUT_OF_DATE` | Projection behind event log | Query before projector caught up |
| `DG_ERR_INVALID_ARGUMENT` | Invalid argument value | limit > 10000, negative offset |
| `DG_ERR_STORAGE` | Storage backend error | Database connection failed |
| `DG_ERR_PII_POLICY_VIOLATION` | Forbidden content detected | Payload contains "Bearer ", etc. |

## Usage Contract

```python
# Catching specific errors
try:
    result = dg.get_trace_summary(trace_id)
except DecisionGraphError as e:
    if e.code == "DG_ERR_NOT_FOUND":
        # Handle not found
        pass
    elif e.code == "DG_ERR_PROJECTION_OUT_OF_DATE":
        # Handle stale projection
        pass
    else:
        raise

# Checking error code
if error.code.startswith("DG_ERR_"):
    # Valid DecisionGraph error
    pass
```

## Subclasses (Optional)

Implementations MAY provide specific subclasses:

```python
class NotFoundError(DecisionGraphError):
    def __init__(self, message: str):
        super().__init__("DG_ERR_NOT_FOUND", message)
```

But catching `DecisionGraphError` and checking `.code` MUST always work.
