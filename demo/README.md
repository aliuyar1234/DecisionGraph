# Demo

This demo builds a deterministic SQLite dataset from the golden fixtures and runs
core queries (trace retrieval, context subgraph, and precedent search).

For a quick user-facing preview, see `demo/SHOWCASE.md`.

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
```

This writes `demo/llm_output.md` and `demo/llm_demo.db` (both ignored by git).
`run_demo.py` and `run_llm_demo.py` only write to paths inside `demo/`.

## Golden E2E Check

```bash
uv run python demo/run_golden_e2e.py
```

This runs a deterministic end-to-end trace and asserts projection digests.

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
