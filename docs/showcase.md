# Showcase

This page shows what users get from DecisionGraph before integration.

## 1. Generate demo dataset

```bash
uv sync
uv run python demo/run_demo.py --db demo/showcase.db --output demo/showcase_output.md --force
```

This builds a deterministic audit dataset with three scenarios:
- `dealdesk`
- `renewal`
- `support`

## 2. Replay projections and verify digests

```bash
uv run python -m decisiongraph replay demo/showcase.db
```

Example output:

```text
Projection digests after replay:
  context_graph: sha256:866b7d3b199949aa92f452840151973ef56387329f00fa4b25f438c636959528
  full_projection: sha256:045813620d5a47e7096eccc53d86d1e484db12bb257e4610536fb97b10d783ec
  precedent_index: sha256:ac214e9522f666636be86f7cf9d86d169c6febc7e68acb38af76ad84785d6be6
  trace_summary: sha256:f985a505c80d3aa7a327c29b264160da1745c712d642e0dfe1b4fe79d29f4ea5
```

## 3. Inspect a complete trace

```bash
uv run python -m decisiongraph dump-trace demo/showcase.db aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
# Optional: include payload and extended metadata
uv run python -m decisiongraph dump-trace demo/showcase.db aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa --include-payload
```

Users can immediately inspect:
- complete ordered event history (`trace_seq`, `log_seq`)
- why the decision happened (`PolicyEvaluated`, `PrecedentCited`, approvals)
- final trace outcome (`TraceFinished`)

## 4. Optional local LLM demo (Ollama)

```bash
uv run python demo/run_llm_demo.py --backend ollama --ollama-model qwen2.5:0.5b
# Optional: persist/show raw model output in the report
uv run python demo/run_llm_demo.py --backend ollama --ollama-model qwen2.5:0.5b --preserve-raw-output
```

This creates:
- `demo/llm_demo.db`
- `demo/llm_output.md`

You can inspect that trace with the same `replay` and `dump-trace` CLI commands.
