# Quickstart: DecisionGraph Foundation

## Installation

```bash
# Clone repository
git clone <repo-url>
cd decisiongraph

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # Linux/macOS
# or: .venv\Scripts\activate  # Windows

# Install in development mode
pip install -e .
```

## Verify Installation

```python
# Check import works
import decisiongraph
print(decisiongraph.__version__)

# Check domain types
from decisiongraph.domain.types import ActorRef, EntityRef, Value

actor = ActorRef(actor_type="agent", actor_id="renewal-agent-v1")
print(actor)

entity = EntityRef(entity_type="Account", entity_id="ACC-123")
print(entity)

value = Value(type="decimal", value="123.45")
print(value)
```

## Verify Error Handling

```python
from decisiongraph.errors import DecisionGraphError

try:
    raise DecisionGraphError("DG_ERR_NOT_FOUND", "Trace not found")
except DecisionGraphError as e:
    print(f"Code: {e.code}")
    print(f"Message: {e.message}")
    print(f"String: {e}")
```

## Run Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=decisiongraph

# Run specific test file
pytest tests/unit/test_bootstrap.py
```

## Verify Module Boundaries

```bash
# Run import-linter
import-linter

# Run type checker
mypy src/

# Run linter
ruff check src/
```

## Project Structure

```
src/decisiongraph/
├── __init__.py      # __version__ exposed here
├── errors.py        # DecisionGraphError
├── ids.py           # UUID utilities
├── time.py          # RFC3339 utilities
└── domain/
    └── types.py     # ActorRef, EntityRef, Value, etc.
```

## Next Steps

After this phase is complete, proceed to `002-event-model` for:
- Event types (TraceStarted, InputObserved, etc.)
- Canonical JSON serialization
- InMemory event store for testing
