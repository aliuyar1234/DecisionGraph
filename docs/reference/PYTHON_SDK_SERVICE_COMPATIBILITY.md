# Python SDK Service Compatibility

## Purpose

This note explains how the existing Python library relates to the new BEAM network service.

The short version:

- Python remains the permanent semantic reference for the frozen Phase 1 scope
- the BEAM service is the shared runtime and operator surface
- both must preserve the same frozen append, replay, ordering, and query guarantees

This document now also records the final Phase 9 compatibility policy and the rules that would apply only if authority is ever reconsidered later.

## What Must Stay Compatible

The HTTP service must preserve the same core semantics documented in:

- `docs/reference/EVENT_ENVELOPE_CONTRACT.md`
- `docs/reference/APPEND_SEMANTICS.md`
- `docs/reference/PRECEDENT_AND_GRAPH_QUERY_SEMANTICS.md`
- `docs/reference/QUERY_AND_ORDERING_INVARIANTS.md`
- `docs/reference/SEMANTIC_PARITY_POLICY.md`

Compatibility means:

- the same event envelope concepts
- the same idempotency and trace-sequence behavior
- the same projection freshness model
- the same deterministic read ordering

It does not mean the transport looks identical to local Python method calls.

## Explicit Compatibility Policy

The compatibility policy is now:

- existing Python local constructors stay local unless a future major release says otherwise
- Python must never silently auto-route local APIs to BEAM HTTP
- remote BEAM usage from Python must be explicit
- a future authority handoff must preserve semantic categories even if transport shape differs

This means the following interpretations are fixed for the current long-term model:

- `DecisionGraph(...)` is local embedded SQLite mode
- `DecisionGraph.from_postgres(...)` is local embedded Postgres mode
- BEAM service access is a separate transport concern, not a hidden constructor side effect

## Local Library vs Network Service

Prefer the Python library when:

- you want embedded local storage
- you need offline or single-process execution
- you are running reference tests or semantic comparisons
- you do not need multi-process operators, Phoenix APIs, or BEAM supervision

Prefer the BEAM service when:

- multiple systems need shared access to one event store
- operators need authenticated replay and health controls
- you want Phoenix-delivered APIs instead of embedding storage in-process
- projector health, lag, and replay jobs should be centrally observable

## Shape Differences

Python library style:

- direct local calls returning Python objects and exceptions

BEAM service style:

- authenticated HTTP requests
- JSON success and error envelopes
- explicit tenant headers
- polling for projection-backed readiness

Those differences are acceptable as long as the underlying semantic outcomes stay aligned.

## Chosen Bridge Direction

Phase 9 did not require a Python-to-BEAM bridge for semantic authority, because Python remains the reference.

The project has now added an explicit Python service client, and the bridge direction is:

- keep `DecisionGraph` as the explicit local/reference API
- add and preserve a separate explicit BEAM service client surface at `decisiongraph.service_client`
- keep migration from local mode to service mode opt-in and visible in code

The project explicitly rejects:

- silent HTTP auto-routing
- changing the meaning of `DecisionGraph(...)` in a patch or minor release
- forcing self-hosted users to guess whether they are talking to a local engine or a network service

## Current Platform Position

What exists now:

- a first authenticated `/api/v1` BEAM service surface
- an explicit Python `DecisionGraphServiceClient` for authenticated BEAM HTTP access
- projection-backed trace, graph, precedent, and health endpoints
- replay and rebuild admin routes with tenant-aware guards

What does not exist yet:

- a stable public migration layer from local Python storage to remote BEAM service usage

What is resolved in a deliberately narrow way:

- the repo now ships an explicit transport client, not a hidden replacement for `DecisionGraph`
- Python helpers should not auto-route to HTTP

The remaining open item is not policy ambiguity anymore; it is how much migration convenience the project wants beyond the explicit client surface.

## Recommended Compatibility Rule

Phase 5 should treat compatibility in this order:

Phase 9 keeps the same ordering:

1. semantic parity first
2. transport stability second
3. convenience wrappers third

That means it is acceptable for the BEAM service to add:

- auth headers
- request IDs
- HTTP status codes
- explicit polling

It is not acceptable for the BEAM service to silently weaken:

- append invariants
- replay determinism
- ordering guarantees
- freshness guarantees

## Embedded-Friendly vs Service-Only

Embedded-friendly Python surfaces that should remain viable even if authority changes later:

- local reference and parity tooling
- frozen fixture bundle generation and consumption
- local CLI/reference workflows
- explicit local embedded execution for offline or single-process use

Service-first platform surfaces:

- authenticated shared-runtime writes
- replay admin controls
- workflow review and escalation
- operator console behavior
- shared self-hosted runtime orchestration

Python may still access the second category, but it should do so through an explicit service client rather than by pretending they are local-library features.

## Versioning Rules

Compatibility-sensitive release rules:

- adding an explicit Python service client is additive and may ship in a minor release
- changing semantic authority is major-only
- changing the default execution mode of an existing Python constructor is major-only
- removing local Python surfaces is major-only and must follow deprecation policy

This repo must not change local Python APIs into remote-default APIs in a patch or minor release.

## Phase 9 Guidance

After Phase 9:

- use Python for semantic reference and embedded workflows
- use BEAM HTTP directly for shared runtime integration, either over raw HTTP or through `DecisionGraphServiceClient`
- keep parity tests grounded in the frozen fixture bundle and reference contracts

With the explicit client now available:

- keep local and remote modes separate and explicit
- preserve semantic error categories across both modes
- publish migration notes before asking users to switch modes
