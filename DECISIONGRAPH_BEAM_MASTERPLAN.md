# DecisionGraph BEAM Master Plan

## Direction

Primary language choice:
- Elixir

Runtime choice:
- BEAM / OTP

Position on Gleam:
- Do not use Gleam as the primary implementation language for this project.
- Re-evaluate Gleam only after the Elixir platform is stable, and only for small pure libraries if it gives a clear advantage.

Why this path:
- The current codebase is already strong as a deterministic reference implementation in Python.
- The biggest upside from BEAM is not syntax; it is supervision, fault tolerance, concurrency, background workers, and long-running service architecture.
- The smartest move is to turn DecisionGraph into a serious Elixir platform without throwing away the Python semantics too early.

## End Product

The end product is a distributed decision intelligence platform with:

- append-only decision event ingestion
- deterministic replay and projection rebuilding
- real-time projection workers and health monitoring
- precedent search and decision similarity workflows
- human approval and exception flows
- investigation-grade trace and graph exploration
- multi-tenant APIs and operational controls
- live operator UI with streaming updates
- Python SDK and service APIs for AI agents and automation systems
- a BEAM-native runtime that can scale into a serious production system

## Core Principles

- Keep the current Python implementation as the semantic reference until BEAM parity is proven.
- Move infrastructure concerns to Elixir first: ingestion, jobs, projections, APIs, realtime, supervision.
- Rewrite pure domain semantics into Elixir only after parity tests are strong enough to make that safe.
- Use Postgres as the primary production datastore for the BEAM platform.
- Treat determinism, replay, and auditability as non-negotiable product features.
- Build the project as if it could become the flagship product, not just a library port.

## Target Architecture

Recommended repo direction:
- keep the current Python package as `reference-core`
- add an Elixir umbrella app for the platform runtime

Recommended BEAM app boundaries:
- `apps/dg_domain` for domain types, validation, event semantics, and contract translation
- `apps/dg_store` for Postgres event store, migrations, and persistence adapters
- `apps/dg_projector` for projection workers, cursors, replay, and digest generation
- `apps/dg_api` for external APIs, auth, ingestion, and query endpoints
- `apps/dg_web` for Phoenix LiveView operator UI
- `apps/dg_observability` for telemetry, metrics, tracing, and health surfaces
- `apps/dg_sdk_bridge` for compatibility helpers and Python-facing integration utilities

## Program Structure

Critical path:
- Phase 0 -> Phase 1 -> Phase 2 -> Phase 3 -> Phase 4 -> Phase 5

Parallelizable later path:
- Phase 6 and Phase 7 can begin after Phase 5 stabilizes
- Phase 8 can begin in parallel with late Phase 6 and Phase 7 work
- Phase 9 is optional and should begin only if earlier phases are successful
- Phase 10 happens after the product is operationally credible

## Phase 0 - North Star and Scope

Goal:
- lock the architectural stance and define the end-state product clearly enough that implementation can proceed without thrashing

Tasks:
- [x] Confirm the official direction: Elixir first, Python as reference, Gleam deferred
- [x] Write a one-page product brief for the final platform
- [x] Define primary user personas: agent builders, platform teams, compliance, operations
- [x] Define the top product differentiators
- [x] Define the v1 platform boundary and the post-v1 wishlist
- [x] Decide repo strategy: monorepo with Python plus Elixir umbrella
- [x] Decide naming conventions for the BEAM apps and public API surfaces
- [x] Decide whether hosted deployment is a goal now or later
- [x] Decide whether the end product should prioritize self-hosted enterprise or cloud-first operation

Phase exit:
- [x] We have a written architecture stance and are not debating language direction anymore
- [x] We know what "impressive end product" means in concrete terms

## Phase 1 - Freeze the Semantic Reference

Goal:
- turn the Python codebase into the official migration oracle

Tasks:
- [x] Freeze the event envelope contract at the reference layer
- [x] Freeze payload shape rules for all current event types
- [x] Freeze trace ordering, idempotency, and replay semantics
- [x] Expand golden fixtures for happy paths, failure cases, and edge conditions
- [x] Add more parity-oriented tests for projections, digests, and query determinism
- [x] Add explicit cross-backend tests for SQLite and Postgres behavior where applicable
- [x] Document the exact invariants that the Elixir implementation must preserve
- [x] Add "reference semantics" docs for append, project, replay, and query behavior
- [x] Add exportable fixture bundles that Elixir tests can consume directly
- [x] Tag a release or internal baseline commit as the semantic reference checkpoint

Phase exit:
- [x] The Python implementation is treated as the truth source for platform parity
- [x] We can prove whether a BEAM port matches or deviates

## Phase 2 - Bootstrap the Elixir Platform

Goal:
- stand up a production-grade Elixir foundation without rewriting the core logic yet

Tasks:
- [x] Create the Elixir umbrella project in the repo
- [x] Set up OTP application boundaries for domain, store, projector, API, and web
- [x] Configure Elixir formatter, Credo, Dialyzer, and test conventions
- [x] Add property-based testing for concurrency-sensitive platform behavior
- [x] Add local development orchestration for Postgres and any required service dependencies
- [x] Add CI for Elixir compile, lint, type analysis, and tests
- [x] Define config strategy for dev, test, staging, and prod
- [x] Add OpenTelemetry baseline instrumentation
- [x] Add structured logging and request correlation conventions
- [x] Add architectural docs for supervision trees and process ownership

Phase exit:
- [x] The repo can build and test both Python and Elixir surfaces cleanly
- [x] The Elixir side is ready to receive real platform features

## Phase 3 - Build the BEAM Event Store

Goal:
- implement the authoritative BEAM-side write model and persistence layer

Tasks:
- [x] Design the Postgres schema for event log, cursors, projections, and metadata
- [x] Implement append-only event persistence in Elixir
- [x] Implement idempotency handling with the same semantics as the Python reference
- [x] Implement trace sequence monotonicity enforcement
- [x] Implement event listing, filtering, and batch iteration APIs
- [x] Implement migration management for the Elixir platform database
- [x] Add write-path telemetry and failure classification
- [x] Add store-level concurrency tests under contention
- [x] Add parity tests that replay Python fixture envelopes through the Elixir store
- [x] Benchmark append throughput and batch-read throughput

Phase exit:
- [x] The Elixir store can safely accept and read events with reference-level semantics
- [x] The store is production-capable for the next phases

## Phase 4 - Build the Projection Runtime

Goal:
- use OTP where it matters most: supervised projection workers, replay coordinators, and projection health management

Tasks:
- [ ] Implement projection worker processes supervised by OTP
- [ ] Implement cursor tracking and projection lag management
- [ ] Implement incremental catch-up processing
- [ ] Implement full replay and rebuild flows
- [ ] Implement deterministic digest generation in Elixir
- [ ] Implement BEAM-side trace summary projection
- [ ] Implement BEAM-side context graph projection
- [ ] Implement BEAM-side precedent index projection
- [ ] Implement retry, backoff, and dead-letter handling for projection failures
- [ ] Implement projection-status and replay admin surfaces in Elixir
- [ ] Add parity tests comparing Elixir projection outputs to Python golden data
- [ ] Add load tests for large replay and catch-up scenarios

Phase exit:
- [ ] The Elixir runtime can ingest, project, replay, and report health with strong confidence
- [ ] We can compare Elixir projection state against Python reference outputs

## Phase 5 - Build the Service API

Goal:
- turn DecisionGraph into a real platform service rather than just a library

Tasks:
- [x] Create the Phoenix API application
- [x] Expose event ingestion endpoints
- [x] Expose trace read endpoints
- [x] Expose context graph query endpoints
- [x] Expose precedent search endpoints
- [x] Expose projection health endpoints
- [x] Expose replay and admin control endpoints with strong safeguards
- [x] Add API authentication and service-account support
- [x] Add tenant-aware authorization rules
- [x] Add rate limiting and abuse protection
- [x] Generate OpenAPI docs for the public surface
- [x] Add end-to-end API tests using real Postgres and projector workers

Phase exit:
- [x] The project is now a usable network service, not just a local library
- [x] External systems can write to and query DecisionGraph through stable APIs

## Phase 6 - Build the Operator UI

Goal:
- make the platform feel impressive and investigation-grade

Tasks:
- [x] Create the Phoenix LiveView operator console
- [x] Build a trace explorer with timeline and payload inspection
- [x] Build a context graph visualizer
- [x] Build a precedent browser and comparison view
- [x] Build a projection health dashboard
- [x] Build a replay console with digest comparison output
- [x] Build a policy and exception review interface
- [x] Build a live event stream view for operators
- [x] Build tenant and environment status pages
- [x] Add polished UI states for loading, failure, and stale projections

Phase exit:
- [x] Operators can investigate real traces and system state from one place
- [x] The project looks and behaves like a serious platform product

## Phase 7 - Human Approval and Workflow Layer

Goal:
- move from passive trace storage to active decision operations

Tasks:
- [x] Implement approval queues and reviewer inboxes
- [x] Implement exception request workflows
- [x] Implement escalation rules and SLA timers
- [x] Implement comments and evidence attachments
- [x] Implement manual override flows with full audit capture
- [x] Implement notifications for approvals, failures, and escalation deadlines
- [x] Implement policy simulation and dry-run workflows
- [x] Implement workflow templates for common business processes
- [x] Implement replay plus review flows for incident analysis
- [x] Add audit-focused exports for approvals and overrides

Phase exit:
- [x] DecisionGraph is now an active control plane for decision workflows
- [x] Human-in-the-loop operation is first-class, not bolted on

## Phase 8 - Multi-Tenancy, Reliability, and Scale

Goal:
- make the platform operationally credible for serious production use

Tasks:
- [ ] Implement organization, workspace, and environment isolation
- [ ] Add tenant-scoped event and projection boundaries
- [ ] Define partitioning strategy for event growth
- [ ] Define archival and retention strategy
- [ ] Add backup and disaster-recovery procedures
- [ ] Add multi-node clustering strategy for the Elixir runtime
- [ ] Add failover and recovery drills
- [ ] Add performance targets and SLOs
- [ ] Add chaos testing for worker crashes and dependency failures
- [ ] Add observability dashboards for throughput, lag, replay duration, and failure rates
- [ ] Add cost and capacity planning for production deployment

Phase exit:
- [ ] The platform can survive real operational stress
- [ ] We understand scaling limits and recovery behavior

## Phase 9 - Optional BEAM-Native Semantic Core

Goal:
- decide whether to keep Python as the permanent semantic reference or migrate core semantics fully into Elixir

Tasks:
- [ ] Decide whether a full semantic rewrite is worth it after the platform proves itself
- [ ] Port pure validation logic into Elixir
- [ ] Port pure event normalization and canonicalization logic into Elixir
- [ ] Port deterministic projection semantics into Elixir where still missing
- [ ] Run the full parity harness against Python fixtures and digests
- [ ] Refuse to switch authoritative semantics until zero-diff or explicitly accepted diffs are proven
- [ ] Keep Python as an SDK and compatibility layer if the BEAM core becomes authoritative
- [ ] Re-evaluate whether Gleam has a role for small pure logic libraries at this stage

Phase exit:
- [ ] We either have a proven BEAM-native semantic core, or we deliberately keep Python as the permanent reference
- [ ] The decision is based on evidence, not enthusiasm

## Phase 10 - Productization and Launch

Goal:
- turn the platform into something launchable, memorable, and hard to ignore

Tasks:
- [ ] Finalize deploy story for self-hosted and optional hosted operation
- [ ] Finalize installation and upgrade guides
- [ ] Finalize production runbooks
- [ ] Finalize versioning and migration policy for the platform APIs
- [ ] Finalize operator and developer docs
- [ ] Build an impressive demo environment with realistic traces and workflows
- [ ] Build benchmark and resilience showcase materials
- [ ] Prepare a beta program with real users or internal stakeholders
- [ ] Gather feedback and close the last major product gaps
- [ ] Cut the first serious platform release

Phase exit:
- [ ] The project is not just technically interesting; it is product-grade
- [ ] We can confidently present it as a standout system

## Immediate Next Steps

If we start now, this is the recommended order:

- [x] Approve this master plan as the working direction
- [x] Open Phase 0 as the active execution phase
- [x] Create a second execution roadmap for Phase 0 and Phase 1 only
- [x] Start by hardening the Python semantic reference before writing BEAM production code
- [x] Add the Elixir umbrella only after the parity target is explicit

## What We Should Not Do

- [ ] Do not start with a full Python-to-Elixir rewrite
- [ ] Do not introduce Gleam early just because it looks elegant
- [ ] Do not build a fancy UI before the write model and projection runtime are solid
- [ ] Do not abandon deterministic parity with the current implementation
- [ ] Do not confuse concurrency benefits with permission to loosen correctness

## Success Criteria

We should consider this transformation successful when:

- [ ] the Elixir platform can ingest and project events reliably under load
- [ ] replay and digest equivalence remain trustworthy
- [ ] operators can inspect traces, graphs, precedents, and health in real time
- [ ] the system supports human approvals and decision workflows cleanly
- [ ] the product feels meaningfully more ambitious than a Python library
- [ ] the architecture is strong enough that adding new decision products becomes easier, not harder
