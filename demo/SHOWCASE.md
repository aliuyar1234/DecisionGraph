# DecisionGraph Showcase

This is a 2-minute preview of what users get before integrating the library.

## 1. Generate a deterministic demo dataset

```bash
uv sync
uv run python demo/run_demo.py --db demo/showcase.db --output demo/showcase_output.md --force
```

This creates a small but realistic audit dataset from golden fixtures:
- 3 scenarios (`dealdesk`, `renewal`, `support`)
- 3 traces
- 26 events

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

## 3. Inspect a real trace as JSON

```bash
uv run python -m decisiongraph dump-trace demo/showcase.db aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
```

What users can see immediately:
- Full ordered event history (`trace_seq`, `log_seq`)
- Why decisions happened (`PolicyEvaluated`, `PrecedentCited`, approvals)
- Final outcome (`TraceFinished`)

## 4. Optional: run with a local LLM via Ollama

```bash
uv run python demo/run_llm_demo.py --backend ollama --ollama-model qwen2.5:0.5b
```

This writes:
- `demo/llm_demo.db`
- `demo/llm_output.md`

Users can then inspect the generated trace with the same CLI commands above.
