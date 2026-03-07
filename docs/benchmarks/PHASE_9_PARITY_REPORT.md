# Phase 9 Parity Report

## Status

Report status:

- final parity report completed on 2026-03-07

Authority decision:

- keep Python authoritative permanently for the frozen Phase 1 scope

Comparison scope:

- frozen Phase 1 semantic reference only

Explicitly excluded from this report unless the baseline is widened later:

- `WorkflowReviewRequested`
- workflow inbox and notification behavior
- service auth and rate limiting
- LiveView operator UX
- self-hosted packaging and release procedures

## Reference Inputs

- `tests/golden/reference_fixture_bundle.json`
- `docs/reference/SEMANTIC_PARITY_POLICY.md`
- `docs/reference/PARITY_HARNESS_PLAN.md`
- `docs/reference/EVENT_ENVELOPE_CONTRACT.md`
- `docs/reference/APPEND_SEMANTICS.md`
- `docs/reference/PROJECTION_AND_REPLAY_SEMANTICS.md`
- `docs/reference/PRECEDENT_AND_GRAPH_QUERY_SEMANTICS.md`
- `docs/reference/QUERY_AND_ORDERING_INVARIANTS.md`
- `docs/reference/DIGEST_INVARIANTS.md`

## Comparison Areas

This report classifies parity across these areas:

- write acceptance and rejection behavior
- idempotency reuse behavior
- trace sequencing and trace-finished locking
- projection snapshots
- component digests and full projection digest
- trace, graph, precedent, and health query behavior
- replay and rebuild outputs
- downstream Python compatibility implications

## Scenario Matrix

| Area | Evidence source | Status | Notes |
| --- | --- | --- | --- |
| Write path parity | `beam/apps/dg_store/test/decision_graph/store/parity_test.exs` | fixed | Frozen bundle scenarios plus idempotency, sequence, and `TraceFinished` lock checks show no observed semantic drift |
| Projection parity | `beam/apps/dg_projector/test/decision_graph/projector/parity_test.exs` | fixed | Trace summary, context graph, precedent index, and digests match the frozen fixture bundle across all bundled scenarios |
| Replay and rebuild | `beam/apps/dg_projector/test/decision_graph/projector/integration_test.exs` | fixed | Catch-up, rebuild, durable cursor resume, replay status persistence, and failure visibility behave consistently with the frozen replay expectations |
| Query ordering and freshness | `beam/apps/dg_projector/test/decision_graph/projector/query_parity_test.exs` | fixed | Trace summary, connected-subgraph traversal, edge pagination, precedent lookup, and stale-read rejection match the frozen query semantics across all bundled scenarios |
| Python compatibility story | `docs/reference/PYTHON_SDK_SERVICE_COMPATIBILITY.md` plus Phase 9 decision docs | intentionally accepted | The project keeps Python as the permanent semantic oracle and local embedded surface, so no authority-handoff bridge is required for Phase 9 completion |

Scenario coverage in the current evidence set:

- `dealdesk`
- `release_rejected`
- `renewal`
- `support`
- `sync_failure`

## Diff Register

This register tracks every meaningful Python-versus-Elixir delta or authority-handoff blocker currently known.

| Area | Scenario or operation | Diff summary | Classification | Action |
| --- | --- | --- | --- | --- |
| Frozen core semantics | bundled writes, projections, queries, and replays | no observed semantic drift in the current BEAM evidence for the frozen Phase 1 scope | fixed | keep the targeted parity suites green and extend them if the frozen reference changes |
| Graph query scope | trace-centered `get_context_subgraph()` versus full projection snapshot | the query returns the connected breadth-first subgraph, not every row present in projection tables; this matches the frozen graph-query contract and is now encoded in the BEAM query parity suite | fixed | keep query expectations connected-subgraph scoped instead of comparing them to raw table dumps |
| BEAM-only workflow semantics | `WorkflowReviewRequested` and workflow runtime behavior | these behaviors do not exist in the frozen Python baseline and therefore do not participate in the authority comparison | intentionally accepted | keep them explicitly out of the authority comparison unless the reference baseline is widened |
| Python consumer transition | embedded Python API, CLI, and SQLite-backed offline mode | the project intentionally keeps this Python-owned compatibility surface instead of forcing a BEAM authority handoff | intentionally accepted | preserve the explicit local Python mode and treat any future service client as additive |

Classification values:

- fixed
- intentionally accepted
- blocking

## Performance And Operability Notes

Parity work surfaced a few important operational and product observations:

- the BEAM platform now shows strong frozen-core parity without needing a risky semantic big-bang rewrite
- the biggest remaining handoff risk is downstream compatibility and governance, not observed correctness drift
- trace-centered graph queries should be evaluated as connected subgraph reads, not as projection-table dumps
- the existing Phase 4, Phase 5, and Phase 8 benchmark baselines remain relevant to the authority decision, but they do not on their own justify moving semantic authority

No current evidence suggests that the frozen core must stay Python-owned because of correctness failures on the BEAM side.
The reason to keep Python authoritative is now a completed product decision: the local and reference Python surface remains valuable enough that a semantic handoff would add cost without enough return.

## Recommendation

Final recommendation:

- keep Python authoritative

Why:

- the frozen Phase 1 write, projection, query, and replay surfaces currently show no observed semantic drift in the checked BEAM evidence
- the remaining differences are either intentionally out of scope or intentionally retained as part of the Python local and reference story
- the BEAM platform already gets the runtime value it needs without replacing the semantic oracle

This means the current Phase 9 answer is:

- BEAM parity is strong enough to support the production platform
- Python remains the permanent semantic oracle for the frozen reference scope
- future authority handoff work is unnecessary unless the product constraints materially change
