# Tasklist

## Infrastruktur
- [x] (P1) Add CI workflow (GitHub Actions) to run `uv run pytest`, `mypy`, `ruff`, and `import-linter` on PRs/pushes.
- [x] (P2) Provide a dev/CI PostgreSQL service (e.g., docker-compose) and wire `PG_CONNINFO` for integration tests so they don't rely on local setup.
- [x] (P3) Remove or relocate `decisions.db` from the repo root (or guarantee it's anonymized) and add a scripted way to generate sample DBs.

## Code Quality / Maintainability
- [x] (P2) Stop reaching into private `SQLiteEventStore._conn` (e.g., `api.py`, `__main__.py`). Expose a public connection accessor or projector factory to keep backends encapsulated.
- [x] (P2) Wrap `SQLiteProjector.project_event` in a transaction + rollback on failure to avoid partially-applied projections.
- [x] (P3) Normalize query validation errors to `DecisionGraphError` (e.g., `PrecedentQuery.__post_init__` currently raises `ValueError`).
- [x] (P3) Add payload schema validation and fail fast instead of silently emitting `unknown` nodes when required fields are missing.

## Performance
- [x] (P2) Batch projection commits when replaying (`project_events` currently commits per event). Provide a bulk API or transaction context.
- [x] (P2) Avoid N+1 edge queries in `get_context_subgraph` by batching frontier nodes or using a recursive CTE.
- [x] (P3) Batch precedent index inserts (use `INSERT ... SELECT` or `executemany`).
- [x] (P3) Revisit precedent search indexing (`find_precedents` uses `LIKE policy:{id}%`), consider dedicated columns/indexes for policy_id/version.

## API Design
- [x] (P1) Provide a public API for recording all event types (or a typed `append_event`) so users don't have to import internal modules.
- [x] (P1) Add backend-agnostic `DecisionGraph` construction + projector for PostgreSQL; queries/projections are SQLite-only today.
- [x] (P2) Expose `replay`/`sync_projections` in the API to recover from stale projections without CLI.
- [x] (P3) Validate `GraphEdgeCursor.direction` against `list_node_edges` arguments to avoid mismatched pagination semantics.

## Database Design
- [x] (P1) Fix projector trace_seq tracking across process restarts (load last seq per trace from DB or compute from log) to avoid false "gap" errors.
- [x] (P2) Strengthen idempotency checks to compare envelope metadata (trace_id/event_type/actor/source) not just `payload_hash`.
- [x] (P2) Make TraceFinished locking atomic (DB constraint or transaction to prevent post-finish inserts under concurrency).
- [x] (P2) Wrap migration apply + schema_migrations insert in one transaction to avoid partial migrations.
- [x] (P3) Revisit placeholder node `trace_id` assignment to avoid cross-trace contamination in projections.

## Security
- [x] (P2) Expand PII guard to be case-insensitive and cover tags/metadata/actor/source fields (currently payload-only, substring-based).
- [x] (P2) Make `dump-trace` read-only (open SQLite in RO mode and avoid migrations/WAL) or update CLI docs to reflect mutations.

## Testing
- [x] (P1) Add regression tests for projector restart with existing traces (trace_seq tracking).
- [x] (P2) Add tests for idempotency key reuse with identical payload but different metadata.
- [x] (P2) Add concurrency tests around TraceFinished locking (multi-writer).
- [x] (P2) Add tests for CLI read-only behavior and for PostgreSQL projection support once implemented.
- [x] (P3) Add tests for pagination cursor direction mismatch.

## V1.0 Hardening (Scope-Locked)

### Scope and Contracts
- [x] (P0) Lock v1 scope in docs: library-only event audit log + projections + queries (no orchestration/policy engine/SaaS features).
- [x] (P0) Freeze public API surface and define semver compatibility rules for `decisiongraph` imports and CLI flags.
- [x] (P1) Freeze event envelope schema and projection table contracts; document allowed additive vs breaking changes.
- [x] (P1) Add API compatibility tests that fail on accidental public-surface changes.

### Determinism and Correctness
- [x] (P0) Add migration compatibility test matrix: replay from every historical migration version to latest and verify digests.
- [x] (P0) Add crash-recovery tests for append/projection boundaries (simulate interruption and restart).
- [x] (P1) Add high-contention multi-writer tests (SQLite + PostgreSQL) for idempotency, trace sequence, and finished-trace locking.
- [x] (P1) Add property/fuzz tests for serialization, validation boundaries, and graph traversal invariants.
- [x] (P1) Add deterministic ordering contract tests for all query endpoints and CLI JSON output modes.

### Performance and Regression Gates
- [x] (P1) Add benchmark suite for core operations (append, trace query, subgraph query, replay).
- [x] (P1) Add CI performance guardrails with fixed budgets and variance thresholds.
- [x] (P2) Add storage-size and replay-time scaling tests (1k, 10k, 100k event fixtures).
- [x] (P0) Enforce coverage thresholds in CI and fail builds when coverage upload/reporting is missing.
- [x] (P1) Add a badge health check so README coverage status cannot degrade to unknown without CI failure.

### Security and Supply Chain
- [x] (P0) Add automated dependency and vulnerability scanning in CI (pip advisory + GitHub alerts review gate).
- [x] (P1) Add static secret scanning and baseline policy for false positives.
- [x] (P1) Add negative tests for path handling, payload redaction defaults, and CLI safe-output behavior.
- [x] (P2) Publish security policy (`SECURITY.md`) with disclosure workflow and supported versions.

### Release and Operations
- [x] (P0) Create release checklist for v1.0: test matrix, docs sync, changelog, signed tag, artifact integrity.
- [x] (P1) Add deprecation policy and migration notes template for future minor/major changes.
- [x] (P1) Add operational runbook: backup/restore, migration rollback strategy, corruption recovery steps.
- [x] (P2) Add reproducibility guide: deterministic digest verification workflow for auditors.
- [x] (P0) Add end-to-end demo smoke tests in CI (CLI demo + deterministic expected output + artifact upload).
- [x] (P1) Add optional local-LLM demo profile docs/checks (Ollama) with graceful skip when model is unavailable.

### V1.0 Exit Criteria (Release Blockers)
- [x] (P0) CI green on Linux/Windows/macOS and Python 3.12/3.13.
- [x] (P0) Zero open critical/high security findings at release cut.
- [x] (P0) Migration compatibility + replay determinism suites pass 100%.
- [x] (P0) Core module coverage target met and enforced in CI.
- [x] (P0) Flaky test rate at or near 0 across repeated CI runs.
- [x] (P0) Demo, CLI examples, and docs snippets execute successfully in CI.
