# Demo

This folder covers the Python semantic-reference demo path.

It builds a deterministic SQLite dataset from the golden fixtures and runs core queries (trace retrieval, context subgraph, and precedent search).

For the BEAM self-hosted release demo, start with:

- `docs/showcase.md`
- `docs/product/DEMO_SCENARIO.md`

For the Python preview, see `demo/SHOWCASE.md`.

## Run

```bash
uv sync
uv run python demo/run_demo.py
```

This writes `demo/output.md` and prints the same report to stdout.

## LLM Demo (local models)

```bash
# Uses D:\models\qwen-1.5b if available, or pass a path explicitly
uv run python demo/run_llm_demo.py --model-path D:\models\qwen-1.5b
# For models that require custom code, opt in explicitly
uv run python demo/run_llm_demo.py --model-path D:\models\qwen-1.5b --allow-remote-code
# Include raw LLM output in report/console only when needed
uv run python demo/run_llm_demo.py --backend ollama --ollama-model qwen2.5:0.5b --preserve-raw-output
# Optional profile check: succeeds with a skip report if Ollama/model is unavailable
uv run python demo/run_llm_demo.py --backend ollama --ollama-model qwen2.5:0.5b --skip-if-unavailable
```

This writes `demo/llm_output.md` and `demo/llm_demo.db` (both ignored by git).
`run_demo.py` and `run_llm_demo.py` only write to paths inside this repository.

## Golden E2E Check

```bash
uv run python demo/run_golden_e2e.py
```

This runs a deterministic end-to-end trace and asserts projection digests.

## CI Demo Smoke

```bash
uv run python scripts/demo_smoke_check.py --artifact-dir .tmp/demo-smoke
```

This validates deterministic demo output (`demo/output.md`) and runs CLI replay/dump checks against a generated DB.

## Keep the SQLite DB

```bash
uv run python demo/run_demo.py --db demo/demo.db --force
```

You can inspect it with the CLI:

```bash
python -m decisiongraph replay demo/demo.db
python -m decisiongraph dump-trace demo/demo.db <trace_id>
python -m decisiongraph dump-trace demo/demo.db <trace_id> --include-payload
```
