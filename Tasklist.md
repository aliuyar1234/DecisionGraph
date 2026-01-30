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
