# Python SDK Service Compatibility

## Purpose

This note explains how the existing Python library relates to the new BEAM network service.

The short version:

- Python remains the semantic reference
- the BEAM service is the shared runtime and operator surface
- both must preserve the same frozen append, replay, ordering, and query guarantees

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

## Current Phase 5 Position

What exists now:

- a first authenticated `/api/v1` BEAM service surface
- projection-backed trace, graph, precedent, and health endpoints
- replay and rebuild admin routes with tenant-aware guards

What does not exist yet:

- a full Python client SDK that wraps the BEAM service
- a committed long-term policy for when Python helpers should auto-route to HTTP
- a stable public migration layer from local Python storage to remote BEAM service usage

## Recommended Compatibility Rule

Phase 5 should treat compatibility in this order:

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

## Near-Term Guidance

Until a dedicated Python network client exists:

- use Python for semantic reference and embedded workflows
- use BEAM HTTP directly for shared runtime integration
- keep parity tests grounded in the frozen fixture bundle and reference contracts
