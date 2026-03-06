# Phase 3 Execution Plan

## Purpose

This file turns Phase 3 from [DECISIONGRAPH_BEAM_MASTERPLAN.md](DECISIONGRAPH_BEAM_MASTERPLAN.md) into an active execution checklist.

Phase 3 is about building the real BEAM event store in `dg_store` while preserving the Python semantic reference defined in `docs/reference/`.

## Phase Goal

By the end of Phase 3 we should have:

- a real Postgres-backed event log owned by `dg_store`
- append semantics that match the Python reference closely
- idempotency and `trace_seq` enforcement implemented in Elixir
- listing and batch-read APIs that later projector work can rely on
- store telemetry, failure classification, and concurrency coverage
- parity evidence showing the BEAM store preserves reference semantics

## Status

Current phase:
- [x] Phase 3 active

Phase complete:
- [x] Phase 3 complete

## Workstreams

- schema and migration design
- write-path semantics
- read-path APIs
- telemetry and failure model
- parity and concurrency testing
- benchmarking and operational docs

## Workstream 1 - Schema and Migration Design

Goal:
- define the authoritative Postgres model for the BEAM write path

Tasks:
- [x] define the event-log schema for envelopes, metadata, payload, and ordering columns
- [x] define indexes for `log_seq`, `trace_id`, `tenant_id`, `event_type`, and idempotency lookup
- [x] decide how projection cursors will be represented for Phase 4 handoff
- [x] decide whether projection tables are created now or reserved for Phase 4 migrations
- [x] define naming conventions for tables, constraints, and indexes
- [x] add the first real Ecto migrations under `beam/apps/dg_store/priv/repo/migrations/`
- [x] document any accepted differences between local-dev and production database settings

Deliverables:
- [x] initial Ecto migration set in `beam/apps/dg_store/priv/repo/migrations/`
- [x] schema notes for event log, metadata, and cursor tables

## Workstream 2 - Write-Path Semantics

Goal:
- make append behavior correct before making it fast

Tasks:
- [x] define the Elixir-side event envelope shape used by `dg_store`
- [x] implement append-only persistence in `DecisionGraph.Store`
- [x] enforce monotonic `trace_seq` behavior per trace
- [x] implement idempotency key reuse semantics matching the Python reference
- [x] preserve metadata consistency checks on idempotent reuse
- [x] define transaction boundaries for append validation plus insert
- [x] decide how write-time canonicalization and digest inputs are handled in Phase 3
- [x] reject invalid or partial writes with stable error categories

Deliverables:
- [x] append API in `beam/apps/dg_store/lib/decision_graph/store.ex`
- [x] persistence implementation backed by Ecto/Postgres
- [x] explicit write semantics documented for Elixir contributors

## Workstream 3 - Read-Path APIs

Goal:
- provide the store APIs needed for projectors, replay, and parity testing

Tasks:
- [x] implement event listing by tenant and trace
- [x] implement deterministic ordering by `log_seq` and `trace_seq` where appropriate
- [x] implement filter support for event type and time-window slices where needed
- [x] implement batch iteration for replay/projector catch-up use
- [x] define pagination and batch-size conventions for internal callers
- [x] add cursor-friendly APIs that later projection workers can consume directly
- [x] make read APIs explicit about consistency and ordering guarantees

Deliverables:
- [x] list and batch APIs in `DecisionGraph.Store`
- [x] test coverage for deterministic ordering and boundary cases

## Workstream 4 - Telemetry and Failure Model

Goal:
- make the write path observable and operable from the start

Tasks:
- [x] emit telemetry for append success, append failure, idempotent reuse, and read batches
- [x] define metadata fields for tenant, trace, event type, and failure reason
- [x] classify datastore errors into stable categories
- [x] define how constraint errors map into domain-level errors
- [x] add structured logging hooks that fit the Phase 2 observability conventions
- [x] record timing and size metrics needed for throughput baselines

Deliverables:
- [x] store telemetry events wired into `dg_observability`
- [x] stable failure mapping for callers and later API layers

## Workstream 5 - Parity and Concurrency Testing

Goal:
- prove semantics, not just implementation shape

Tasks:
- [x] add store-level ExUnit coverage for append and read behavior
- [x] add contention tests for concurrent appends to the same trace
- [x] add tests for concurrent appends across different traces and tenants
- [x] replay the Python reference fixture bundle through the Elixir store
- [x] assert parity for ordering, idempotency reuse, and rejection behavior
- [x] add property-style tests where concurrency rules benefit from generated coverage
- [x] verify migration setup and teardown behavior in test environments

Deliverables:
- [x] parity-focused test suite under `beam/apps/dg_store/test/`
- [x] fixture-bundle consumption path from `tests/golden/reference_fixture_bundle.json`
- [x] explicit report of any intentional semantic gaps

## Workstream 6 - Benchmarking and Operational Docs

Goal:
- leave Phase 3 with credible performance and operating guidance

Tasks:
- [x] benchmark append throughput for representative event sizes
- [x] benchmark batch-read throughput for projector-style workloads
- [x] document expected local-dev setup for running Phase 3 tests and benchmarks
- [x] document the current store contract for later Phase 4 and Phase 5 work
- [x] capture known limitations that are acceptable before projection-runtime work begins

Deliverables:
- [x] baseline benchmark notes for append and batch-read performance
- [x] store contract doc or section linked from the main docs set

## Reference Inputs

Phase 3 must stay aligned with these existing reference assets:

- `docs/reference/EVENT_ENVELOPE_CONTRACT.md`
- `docs/reference/APPEND_SEMANTICS.md`
- `docs/reference/STORAGE_BACKEND_EXPECTATIONS.md`
- `docs/reference/QUERY_AND_ORDERING_INVARIANTS.md`
- `docs/reference/SEMANTIC_PARITY_POLICY.md`
- `tests/golden/reference_fixture_bundle.json`

If Elixir behavior differs from those assets, the difference must be either fixed or explicitly documented as an accepted deviation.

## Exit Criteria

Phase 3 is complete only when:

- [x] the BEAM store can append events safely into Postgres
- [x] idempotency behavior matches the Python reference closely enough to trust it
- [x] `trace_seq` monotonicity is enforced under contention
- [x] deterministic event reads and batch iteration are available for later projector work
- [x] store telemetry and failure mapping are good enough for operator-facing surfaces
- [x] parity tests show the Elixir store preserves agreed reference semantics
- [x] the repo still validates cleanly across Python and Elixir quality gates

## Recommended Execution Order

1. schema and migrations
2. append semantics and idempotency
3. deterministic read APIs
4. telemetry and failure mapping
5. parity plus concurrency tests
6. benchmarking and store docs

## Immediate Next Actions

- [x] write the first Postgres schema sketch for the event log and cursor tables
- [x] add the initial Ecto migrations in `dg_store`
- [x] implement the first append API skeleton in `DecisionGraph.Store`
- [x] port the first idempotency and ordering tests from the Python reference
- [x] decide the exact boundary between Phase 3 store tables and Phase 4 projection tables

## Completion Summary

Phase 3 is complete in code and docs.

Implemented artifacts:

- Postgres migrations for `dg_event_log` and `dg_projection_cursors`
- BEAM-side envelope normalization, validation, canonical hashing, and `StoredEvent` mapping
- `DecisionGraph.Store` append, list, trace, batch, cursor, and maintenance APIs
- telemetry emission and domain-level error mapping
- store, concurrency, parity, and migration-oriented ExUnit coverage
- local benchmark task: `mix dg.store.bench`
- store contract and benchmark docs for the next phase handoff
