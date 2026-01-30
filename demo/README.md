# Demo

This demo builds a deterministic SQLite dataset from the golden fixtures and runs
core queries (trace retrieval, context subgraph, and precedent search).

## Run

```bash
uv sync
uv run python demo/run_demo.py
```

This writes `demo/output.md` and prints the same report to stdout.

## Keep the SQLite DB

```bash
uv run python demo/run_demo.py --db demo/demo.db --force
```

You can inspect it with the CLI:

```bash
python -m decisiongraph replay demo/demo.db
python -m decisiongraph dump-trace demo/demo.db <trace_id>
```
