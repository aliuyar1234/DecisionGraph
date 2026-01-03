# Quickstart: E2E Integration & Documentation

## Prerequisites

- 001-006 completed and installed

## Run Golden Fixture Tests

```bash
# Run all E2E tests
pytest tests/e2e/ -v

# Run fixture tests only
pytest tests/e2e/test_fixtures.py -v

# Run specific scenario
pytest tests/e2e/test_fixtures.py::test_renewal_digest -v
```

## Validate Fixtures Manually

```python
from decisiongraph.testing.golden import load_fixture, validate_fixture
from pathlib import Path

# Load a fixture
fixture = load_fixture(Path("tests/golden/renewal"))
print(f"Scenario: {fixture.scenario}")
print(f"Events: {len(fixture.events)}")

# Validate digest matches
if validate_fixture(Path("tests/golden/renewal")):
    print("✓ Digest matches expected")
else:
    print("✗ Digest mismatch!")
```

## Use CLI (Optional)

```bash
# Rebuild projections and print digest
python -m decisiongraph replay decisiongraph.db

# Dump trace events
python -m decisiongraph dump-trace decisiongraph.db b3b0a4a8-...
```

## Create New Fixture

```python
from decisiongraph import DecisionGraph
from decisiongraph.testing.golden import export_fixture

# Run your scenario
dg = DecisionGraph(":memory:")
trace_id = dg.start_trace(...)
# ... emit events ...
dg.finish_trace(trace_id, ...)

# Export as fixture
export_fixture(
    store=dg._store,
    trace_id=trace_id,
    output_path=Path("tests/golden/new_scenario")
)
```

## Verify No Chain-of-Thought

```python
from decisiongraph.testing.golden import check_no_cot

fixture = load_fixture(Path("tests/golden/renewal"))

# Check for forbidden content
if check_no_cot(fixture):
    print("✓ No Chain-of-Thought content")
else:
    print("✗ Contains forbidden content!")
```

## Test README Examples

```python
# In test_docs.py
import subprocess

def test_readme_examples_run():
    # Extract code blocks from README
    # Execute each one
    # Verify no errors
    ...
```

## Fixture Locations

```
tests/golden/
├── renewal/
│   ├── events.json
│   └── expected_digest.txt
├── support/
│   ├── events.json
│   └── expected_digest.txt
└── dealdesk/
    ├── events.json
    └── expected_digest.txt
```

## Test Cases

| ID | Name | Description |
|----|------|-------------|
| TC-P6-001 | fixture_renewal_digest | Renewal scenario digest matches |
| TC-P6-002 | fixture_renewal_queries | Renewal queries return expected |
| TC-P6-003 | fixture_support_digest | Support scenario digest matches |
| TC-P6-004 | fixture_support_queries | Support queries return expected |
| TC-P6-005 | fixture_dealdesk_digest | Deal Desk digest matches |
| TC-P6-006 | fixture_dealdesk_queries | Deal Desk queries return expected |
| TC-P6-007 | cli_replay_outputs_digest | CLI replay prints correct digest |
| TC-P6-008 | cli_dump_trace_stable | CLI dump is deterministic |
| TC-P6-009 | docs_examples_compile | README examples run |
| TC-P6-010 | no_chain_of_thought | No CoT in fixtures |
