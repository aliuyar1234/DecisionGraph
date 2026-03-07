# DecisionGraph Python Showcase

This is the semantic-reference showcase for the Python package.

If you want the current self-hosted BEAM platform demo instead, use:

- `docs/showcase.md`

## 1. Generate A Deterministic Demo Dataset

```bash
uv sync
uv run python demo/run_demo.py --db demo/showcase.db --output demo/showcase_output.md --force
```

This creates a small but realistic audit dataset from golden fixtures:
- 5 scenarios (`dealdesk`, `release_rejected`, `renewal`, `support`, `sync_failure`)
- 5 traces
- 40 events

## 2. Replay Projections And Verify Digests

```bash
uv run python -m decisiongraph replay demo/showcase.db
```

Example output:

```text
Projection digests after replay:
  context_graph: sha256:57870a0d6ef5f07dbf79eb53c642987582f102f05bc06de3d94d709ea43c57b1
  full_projection: sha256:e912b7080ed689e1031e963c1cb33ca3acd752952876d5f446c12329f2673614
  precedent_index: sha256:a87cf8124584225fd87e80cbd573dc40af912e4c92b48621928edec9dadc9251
  trace_summary: sha256:5c5d5c3bfb68b74818e1f5c742522154c5ab0711b09c0cdea8eb02a110b391dd
```

## 3. Inspect A Real Trace As JSON

```bash
uv run python -m decisiongraph dump-trace demo/showcase.db aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
# Optional: include payload and extended metadata
uv run python -m decisiongraph dump-trace demo/showcase.db aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa --include-payload
```

What users can see immediately:
- Full ordered event history (`trace_seq`, `log_seq`)
- Why decisions happened (`PolicyEvaluated`, `PrecedentCited`, approvals)
- Final outcome (`TraceFinished`)

## 4. Optional: Run With A Local LLM Via Ollama

```bash
uv run python demo/run_llm_demo.py --backend ollama --ollama-model qwen2.5:0.5b
# Optional: persist/show raw model output in the report
uv run python demo/run_llm_demo.py --backend ollama --ollama-model qwen2.5:0.5b --preserve-raw-output
```

This writes:
- `demo/llm_demo.db`
- `demo/llm_output.md`

Users can then inspect the generated trace with the same CLI commands above.
