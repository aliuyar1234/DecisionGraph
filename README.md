# DecisionGraph

Event-sourced decision audit trail for AI agents.

[![CI](https://github.com/aliuyar1234/DecisionGraph/actions/workflows/ci.yml/badge.svg?label=CI)](https://github.com/aliuyar1234/DecisionGraph/actions/workflows/ci.yml)
[![Coverage](https://codecov.io/gh/aliuyar1234/decisiongraph/branch/master/graph/badge.svg)](https://app.codecov.io/github/aliuyar1234/decisiongraph)
[![Demo](https://github.com/aliuyar1234/DecisionGraph/actions/workflows/demo.yml/badge.svg?label=Demo)](https://github.com/aliuyar1234/DecisionGraph/actions/workflows/demo.yml)
[![Docs](https://img.shields.io/badge/docs-github--pages-blue)](https://aliuyar1234.github.io/DecisionGraph/)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.12-blue.svg)](https://www.python.org/)

## At a Glance

- **Append-only audit log** of decision events
- **Deterministic digests** to verify replays
- **Local-first** (SQLite/PostgreSQL), no service required
- **Strict validation + PII guard** built in

## Why DecisionGraph?

When AI agents make decisions (approving discounts, escalating tickets, routing requests) you need an immutable audit trail that answers:

- **What happened?** Complete trace of observations, evaluations, and actions
- **Why?** Policy citations, precedent references, approval chains
- **Can we reproduce it?** Deterministic projection digests for verification

DecisionGraph is a library, not a service. Embed it directly in your agent code.

### Use cases

- Compliance/audit trails for agent decisions
- Exception workflows with approvals and precedent tracking
- Reproducible evaluations for safety and policy changes

## Quickstart

```bash
git clone https://github.com/aliuyar1234/DecisionGraph.git
cd DecisionGraph
uv sync

# With PostgreSQL support
uv sync --extra postgres
```

```python
from decisiongraph import DecisionGraph
from decisiongraph.domain.types import ActorRef, EntityRef, SourceRef

dg = DecisionGraph(":memory:")

# Define context
source = SourceRef(producer_id="renewal-agent", system="agent-platform")
actor = ActorRef(actor_type="agent", actor_id="renewal-v1")
customer = EntityRef(entity_type="account", entity_id="acct-123", system="salesforce")

# Record a decision trace
trace_id = dg.start_trace(
    workflow="renewal",
    title="15% discount request for Acme Corp",
    primary_entity=customer,
    source=source,
    actor=actor,
)

# Finish the trace
dg.finish_trace(trace_id, outcome="success", source=source, actor=actor)

# Query later
events = dg.get_trace_events(trace_id)
print(f"Recorded {len(events)} events")
```

## 2-Minute Showcase

Want to see what users will experience before integrating?

```bash
uv run python demo/run_demo.py --db demo/showcase.db --output demo/showcase_output.md --force
uv run python -m decisiongraph replay demo/showcase.db
uv run python -m decisiongraph dump-trace demo/showcase.db aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
# Include payload + extended metadata only when explicitly needed:
uv run python -m decisiongraph dump-trace demo/showcase.db aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa --include-payload
```

See the full walkthrough in [demo/SHOWCASE.md](demo/SHOWCASE.md).

### PostgreSQL (dev/CI)

```bash
docker compose up -d postgres
export PG_CONNINFO="host=localhost port=5432 dbname=decisiongraph_test user=decisiongraph password=decisiongraph"
```

## Demo

```bash
uv run python demo/run_demo.py
```

See `demo/output.md` for the generated report and `demo/README.md` for details.

### Golden E2E Check

```bash
uv run python demo/run_golden_e2e.py
```

This runs a deterministic end-to-end trace and asserts projection digests.

### LLM Demo (local models)

```bash
uv run python demo/run_llm_demo.py --model-path D:\models\qwen-1.5b
# For models that require custom code, opt in explicitly:
uv run python demo/run_llm_demo.py --model-path D:\models\qwen-1.5b --allow-remote-code
# Raw LLM output is hidden by default; opt in to persist/show it:
uv run python demo/run_llm_demo.py --backend ollama --ollama-model qwen2.5:0.5b --preserve-raw-output
```

This runs a real local model and persists the trace to `demo/llm_demo.db`.
Demo scripts only write to paths inside this repository.

## Documentation

Full docs at https://aliuyar1234.github.io/DecisionGraph/

## Sample Database

```bash
python scripts/generate_sample_db.py --output sample.db
```

## Architecture

```
+-------------------------------------------------------------+
|                      DecisionGraph API                       |
+-------------------------------------------------------------+
                              |
         +--------------------+--------------------+
         v                    v                    v
+-----------------+  +-----------------+  +-----------------+
|   Event Store   |  |   Projector     |  |   Query Layer   |
|  append-only    |  |  deterministic  |  |  trace, graph,  |
|  log_seq order  |  |  replay         |  |  precedents     |
+-----------------+  +-----------------+  +-----------------+
                              |
              +---------------+---------------+
              v                               v
      +-------------+                 +-------------+
      |   SQLite    |                 |  PostgreSQL |
      +-------------+                 +-------------+
```

### Concepts

| Concept | Description |
|---------|-------------|
| **Trace** | Decision workflow from start to finish |
| **Event** | Immutable record: observation, evaluation, approval, action |
| **Projection** | Derived view: context graph, trace summaries, precedent index |
| **Digest** | SHA-256 hash for reproducibility verification |

### Event Flow

```
TraceStarted -> EntityObserved -> PolicyEvaluated -> ApprovalRecorded -> ActionCommitted -> TraceFinished
```

## Queries

Find precedents and explore context:

```python
# Find similar past decisions
precedents = dg.find_precedents(policy_id="discount_cap", outcome="success")

# Explore context graph around an entity
subgraph = dg.get_context_subgraph(node_type="entity", node_id="acct-123", max_depth=2)
```

## CLI

```bash
# Rebuild projections, print digests
python -m decisiongraph replay sample.db

# Dump trace as JSON (payload hidden by default)
python -m decisiongraph dump-trace sample.db trace-123
# Include payload + extended metadata when needed
python -m decisiongraph dump-trace sample.db trace-123 --include-payload
```

## Design Principles

1. **Append-only**: Events are immutable. No updates, no deletes.
2. **Deterministic**: Same events = same projection digest. Always.
3. **Library-first**: No background processes, no network calls.
4. **Explicit**: IDs are passed, not inferred.
5. **Fail fast**: Invalid payloads, PII patterns -> immediate error.

## Non-Goals

- Not a workflow engine (records decisions, doesn't orchestrate)
- Not a policy engine (evaluate elsewhere, record here)
- Not real-time (optimized for audit, not streaming)

## Performance

| Operation | Target |
|-----------|--------|
| Append event | < 5ms |
| Query trace (100 events) | < 10ms |
| Subgraph (depth=2) | < 50ms |
| Precedent search (1K traces) | < 100ms |
| Full rebuild (10K events) | < 5s |

## Development

```bash
uv sync
uv run pytest
uv run mypy src/ --strict
uv run ruff check src/
uv run lint-imports
```

### Docs

```bash
uv sync --extra docs
uv run mkdocs serve
```

### Pre-commit

```bash
uv run pre-commit install
```

## Contributing

See `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md`.

## Test Coverage

**400+ tests** covering:

| Category | Tests | Coverage |
|----------|-------|----------|
| Unit tests | 300+ | Domain types, events, validation, serialization, projections |
| Integration tests | 80+ | SQLite/PostgreSQL backends, projection replay, queries |
| E2E tests | 50+ | API workflows, CLI commands, golden fixtures |

Key areas tested:
- **Storage**: Idempotency conflicts, trace sequence validation, transaction rollback
- **Projections**: Hash verification, gap detection, cursor tracking, rebuild
- **Queries**: Staleness detection, pagination, filtering, graph traversal
- **Validation**: PII guard patterns, idempotency key limits, JSON safety
- **Serialization**: Unicode handling, deep nesting, hash stability

```bash
# Run all tests
uv run pytest

# Run with coverage
uv run pytest --cov=decisiongraph
```

## Structure

```
src/decisiongraph/
    api.py              # High-level facade
    domain/             # Event types, validation
    storage/            # SQLite + PostgreSQL
    projections/        # Context graph, digests
    query/              # Trace, graph, precedent queries
    testing/            # Golden fixtures

tests/
    unit/
    integration/
    e2e/
    golden/             # Deterministic replay fixtures
```

## Support

For bugs or feature requests, open an issue: https://github.com/aliuyar1234/DecisionGraph/issues  
For questions, use Discussions: https://github.com/aliuyar1234/DecisionGraph/discussions

## License

Apache-2.0
