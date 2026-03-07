# Phase 9 Semantic Authority Recommendation

## Recommendation

DecisionGraph should keep Python as the permanent semantic authority for the frozen Phase 1 scope after Phase 9.

This is a deliberate architectural choice, not a lack of confidence in the BEAM platform.

## Why This Is The Right Opening Position

The BEAM side is already strong where the platform needed it most:

- production-style event storage
- supervised projection runtime
- authenticated service APIs
- operator console
- workflow and review operations
- self-hosted operational credibility

That success does not automatically answer the semantic-authority question.

The final Phase 9 evidence shows no observed frozen-core semantic drift across the current BEAM write, projection, query, and replay proof suites.

Even with that result, three issues make a handoff unnecessary or counterproductive:

### 1. The Remaining Cost Is Transition Cost, Not Core Correctness Cost

The repo now has a completed parity decision artifact in `docs/benchmarks/PHASE_9_PARITY_REPORT.md`.
That report is good news for correctness, but it does not create enough product value to justify an authority handoff by itself.

### 2. Python Still Owns A Real Compatibility Surface

The Python package still matters for:

- embedded local usage
- SQLite-backed execution
- offline or single-process workflows
- the local CLI and semantic reference harness

If Elixir becomes authoritative, that surface needs an explicit bridge or retirement policy.

### 3. The BEAM Platform Has Newer Semantics Outside The Frozen Baseline

The BEAM platform added workflow-era behavior such as `WorkflowReviewRequested`.
That is valid product evolution, but it is not part of the original frozen Python semantic baseline.

The project should avoid using newer BEAM-only extensions as evidence that the original reference core has already been replaced.

## Practical Recommendation For Maintainers

Phase 9 should end with this operating model:

1. keep Python authoritative for the frozen core
2. use the Phase 9 parity report as the release gate for frozen-core BEAM parity
3. keep the Python local-library, CLI, and SQLite story as intentional product value
4. treat any future authority handoff as a new decision, not the default continuation of this phase

## What Would Change This Recommendation

I would recommend BEAM authority in a future phase only after all of the following are true:

- the Phase 9 parity report remains complete and diff-classified
- no non-negotiable semantic drift remains
- the Python consumer transition policy is written
- rollback and governance are explicit
- maintainers can explain the user benefit of the handoff, not just the implementation neatness

## Why Keeping Python Authoritative Is The Final Phase 9 Outcome

Keeping Python as the permanent oracle is the right successful outcome because:

- BEAM already delivers the runtime and product value users need
- Python continues to serve the embedded reference and offline use cases well
- an independent oracle keeps parity discipline strong
- a full handoff would create migration work without meaningful product upside for the local-first strategy

That outcome does not mean BEAM fell short.
It means the project now has a stable long-term split of responsibilities.
