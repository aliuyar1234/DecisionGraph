# Semantic Authority Inventory

## Purpose

This inventory defines what "semantic authority" actually covers in DecisionGraph.

Phase 9 is not deciding whether the BEAM platform is successful.
That has already been proven enough to reach this phase.
Phase 9 is deciding whether the frozen Python semantic reference can remain the long-term oracle, or whether the pure semantic core can safely move into Elixir.

## Final Phase 9 Position

- Python remains the permanent semantic authority for the frozen Phase 1 scope.
- The BEAM platform already owns runtime, supervision, APIs, operators, and workflow delivery.
- Several frozen semantic areas already have strong BEAM parity evidence.
- A full authority handoff is not being pursued because the remaining cost is transition and governance cost rather than missing BEAM semantic capability.

## What Counts As Semantic Authority

Semantic authority includes the observable rules that must stay stable across implementations:

- event vocabulary and envelope meaning
- payload validation and PII guard behavior
- canonical JSON and payload-hash generation
- append invariants, idempotency, ordering, and trace locking
- projection outputs and deterministic digests
- projection freshness checks and query ordering
- replay and rebuild outputs for the same stored events

Semantic authority does not include:

- Phoenix transport details
- OTP supervision topology
- replay job orchestration mechanics
- service authentication and rate limiting
- LiveView console behavior
- self-hosted install or release packaging
- workflow inbox UX and notifications

Those are important platform concerns, but they are not part of the frozen Python semantic oracle.

## Inventory By Area

### 1. Event Vocabulary And Envelope Contract

Python reference:

- `src/decisiongraph/domain/events.py`
- `docs/reference/EVENT_ENVELOPE_CONTRACT.md`

BEAM implementation:

- `beam/apps/dg_domain/lib/decision_graph/domain/event_envelope.ex`
- `beam/apps/dg_domain/lib/decision_graph/domain.ex`
- `beam/apps/dg_domain/lib/decision_graph/domain/event_types.ex`

Current status:

- The frozen Phase 1 event vocabulary is mirrored on the BEAM side.
- The BEAM platform also introduced `WorkflowReviewRequested`, which is a platform-era extension and not part of the original frozen Python semantic baseline.

Authority implication:

- The frozen event envelope is close to handoff-ready for the original Phase 1 scope.
- `WorkflowReviewRequested` must stay explicitly out of the authority comparison scope unless Python gains a matching reference contract or the project formally widens the baseline.

### 2. Payload Validation And PII Guard

Python reference:

- `src/decisiongraph/domain/validation.py`
- `tests/unit/test_validation_boundary.py`
- `tests/unit/test_pii_guard.py`

BEAM implementation:

- `beam/apps/dg_domain/lib/decision_graph/domain/validation.ex`
- `beam/apps/dg_store/lib/decision_graph/store/prepared_event.ex`

Current status:

- BEAM validates the frozen event payloads and PII rules.
- BEAM also validates the BEAM-only workflow review event.
- The validation logic is already pure and invoked through the BEAM append-normalization pipeline before writes are stored.

Authority implication:

- This area is a legitimate candidate for BEAM authority.
- Before handoff, the project still needs a Phase 9 diff classification pass proving no unreviewed differences remain for frozen events.

### 3. Canonical JSON And Payload Hashing

Python reference:

- `src/decisiongraph/serialization/canonical_json.py`
- `src/decisiongraph/serialization/hashing.py`
- `tests/unit/test_canonical_json.py`
- `tests/unit/test_serialization_edge_cases.py`

BEAM implementation:

- `beam/apps/dg_domain/lib/decision_graph/domain/canonical_json.ex`
- `beam/apps/dg_domain/test/decision_graph/domain/canonical_json_test.exs`

Current status:

- Canonical JSON generation exists as a pure Elixir module.
- Payload-hash generation is already BEAM-native.
- Prior Phase 4 parity work fixed known boolean and `nil` canonicalization drift.

Authority implication:

- This is one of the strongest candidates for authority handoff.
- It already behaves like a BEAM-owned pure semantic primitive, even though Python remains the official oracle.

### 4. Append, Ordering, Idempotency, And Trace Locking

Python reference:

- `src/decisiongraph/storage/_shared.py`
- `src/decisiongraph/storage/sqlite/backend.py`
- `src/decisiongraph/storage/postgres/backend.py`
- `docs/reference/APPEND_SEMANTICS.md`
- `docs/reference/QUERY_AND_ORDERING_INVARIANTS.md`

BEAM implementation:

- `beam/apps/dg_store/lib/decision_graph/store.ex`
- `beam/apps/dg_store/test/decision_graph/store/parity_test.exs`
- `beam/apps/dg_store/test/decision_graph/store/concurrency_test.exs`

Current status:

- BEAM owns the production write path and Postgres event store.
- Idempotent reuse, trace sequencing, and post-`TraceFinished` locking have parity-oriented BEAM tests.
- The self-hosted platform already relies on the BEAM store as the operational write surface.

Authority implication:

- Observable write semantics have strong evidence and are close to a possible BEAM authority decision.
- Embedded SQLite behavior is still Python-owned and must be treated as a compatibility question rather than silently assumed equivalent.

### 5. Projection Outputs And Deterministic Digests

Python reference:

- `src/decisiongraph/projections/context_graph.py`
- `src/decisiongraph/projections/projector.py`
- `src/decisiongraph/projections/digests.py`
- `docs/reference/PROJECTION_AND_REPLAY_SEMANTICS.md`
- `docs/reference/DIGEST_INVARIANTS.md`

BEAM implementation:

- `beam/apps/dg_projector/lib/decision_graph/projector/context_graph.ex`
- `beam/apps/dg_projector/lib/decision_graph/projector/write.ex`
- `beam/apps/dg_projector/lib/decision_graph/projector/digests.ex`
- `beam/apps/dg_projector/test/decision_graph/projector/parity_test.exs`

Current status:

- Trace summary, context graph, precedent index, and full projection digests are implemented on the BEAM side.
- The frozen fixture bundle is already used for projector parity.
- Phase 4 fixed the prior parity drift and established a checked-in digest baseline.
- The checked-in Phase 9 parity report now classifies this surface as having no observed frozen-core drift.

Authority implication:

- Projection semantics are another strong BEAM-native candidate.
- The remaining authority blocker is no longer projection correctness; it is transition and governance closure.

### 6. Query Semantics And Freshness Safeguards

Python reference:

- `src/decisiongraph/query/events.py`
- `src/decisiongraph/query/graph.py`
- `src/decisiongraph/query/precedents.py`
- `src/decisiongraph/query/health.py`
- `docs/reference/PRECEDENT_AND_GRAPH_QUERY_SEMANTICS.md`
- `docs/reference/QUERY_AND_ORDERING_INVARIANTS.md`

BEAM implementation:

- `beam/apps/dg_projector/lib/decision_graph/projector/query.ex`
- `beam/apps/dg_api/lib/decision_graph/api/events.ex`
- `beam/apps/dg_api/lib/decision_graph/api/graph.ex`
- `beam/apps/dg_api/lib/decision_graph/api/precedents.ex`

Current status:

- BEAM query behavior exists for trace summaries, graph traversal, graph edge pagination, precedent search, and projection health.
- The implementation follows the frozen ordering and staleness rules.
- Evidence now exists through projector tests, API tests, service E2E coverage, and the dedicated Phase 9 query parity suite.

Authority implication:

- This area is now formally exercised as part of the Phase 9 parity report for the frozen scope.
- The remaining handoff blocker is not observed query drift, but Python transition policy and governance.

### 7. Python Embedded Library Surface, CLI, And SQLite Mode

Python reference:

- `src/decisiongraph/api.py`
- `src/decisiongraph/__main__.py`
- `src/decisiongraph/storage/sqlite/backend.py`
- `tests/e2e/test_cli.py`
- `tests/integration/test_sqlite_backend.py`

BEAM counterpart:

- no direct BEAM embedded-library equivalent
- service/API equivalents live under `beam/apps/dg_api/` and `beam/apps/dg_web/`

Current status:

- The Python package still owns the embedded local library experience.
- The CLI and SQLite-backed offline mode remain Python-first.
- The BEAM platform replaces the shared service runtime, not the embedded library ergonomics.

Authority implication:

- A BEAM semantic handoff does not automatically replace the Python package's local usability story.
- Any authority change must preserve or intentionally retire this compatibility surface through an explicit SDK bridge decision.

### 8. BEAM-Only Workflow And Review Extensions

BEAM implementation:

- `beam/apps/dg_domain/lib/decision_graph/domain/validation.ex`
- `beam/apps/dg_api/lib/decision_graph/api/workflows.ex`
- `beam/apps/dg_store/priv/repo/migrations/20260307000600_allow_workflow_review_requested_event_type.exs`

Current status:

- `WorkflowReviewRequested` and the workflow runtime are product-era BEAM extensions.
- They are operationally important, but they are not part of the frozen Python reference bundle.

Authority implication:

- These behaviors are BEAM-owned platform semantics.
- They must stay out of the core authority comparison until the project intentionally expands the frozen semantic baseline.

## Pure Logic vs Platform Ownership

The cleanest Phase 9 split is:

Pure semantic logic:

- event vocabulary
- envelope normalization
- payload validation
- canonical JSON
- payload hashing
- query filters and ordering rules
- graph emission and digest composition

Platform or operational logic:

- Ecto and SQL adapter details
- GenServer and supervisor ownership
- replay job scheduling
- HTTP controllers and auth
- LiveView console state
- workflow routing, escalation, and notifications
- self-hosted operations and release mechanics

Phase 9 should only move the first category.
It should not try to rename normal platform evolution as "semantic migration."

## Phase 9 Resolution Snapshot

The questions that mattered during Phase 9 resolved like this:

- the checked-in Phase 9 parity report shows no observed frozen-core drift
- the Python package intentionally keeps the embedded SQLite and offline library story
- BEAM-only workflow extensions stay out of the frozen comparison scope
- downstream compatibility, transition, and governance rules are now documented instead of implicit

## Recommended Long-Term Interpretation

After Phase 9, the repo should be interpreted like this:

- Python owns semantic authority for the frozen Phase 1 reference scope
- BEAM owns runtime authority for production-style self-hosted operation and platform-era extensions
- some pure semantic primitives are mirrored in Elixir for runtime parity, but that does not change the semantic oracle
- any future handoff would require a new ADR and intentionally different product conditions
