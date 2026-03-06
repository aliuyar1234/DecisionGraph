# ADR: Elixir as the Primary BEAM Platform Language

## Status

Accepted

## Date

2026-03-06

## Context

The current DecisionGraph codebase is a strong Python reference implementation for deterministic event capture, projection building, replay, and query behavior.

The next product ambition is larger than a library:

- supervised long-running workers
- replay orchestration
- realtime health and operator surfaces
- approval and exception workflows
- service APIs
- eventually multi-tenant, multi-node runtime behavior

Those platform concerns benefit from BEAM and OTP much more than from staying library-only.

We considered three broad options:

- remain Python-first everywhere
- adopt Elixir on BEAM
- adopt Gleam on BEAM as the primary implementation language

## Decision

DecisionGraph will use Elixir as the primary BEAM platform language.

More specifically:

- BEAM and OTP are the target runtime foundation for the future platform
- Elixir is the default implementation language for BEAM-side platform work
- Gleam is explicitly deferred as a non-primary choice
- Phoenix will be the platform delivery layer for APIs, operator UI, and realtime features
- Postgres will be treated as the primary production datastore for the future platform

## Rationale

Elixir is the right choice for this stage because it gives us:

- mature OTP ergonomics for supervision and concurrency
- strong Phoenix and LiveView integration
- a practical path to realtime and operator-facing product surfaces
- a larger and better-documented ecosystem for service and platform work than Gleam
- a faster route from architecture plan to production implementation

Gleam remains interesting for typed BEAM development, but the project's near-term needs are platform delivery, runtime behavior, and supervision-heavy implementation. Elixir is the more practical fit for that.

## Consequences

### Positive

- we can build a serious operational platform instead of only evolving the Python library
- runtime concerns like replay, lag monitoring, approvals, and health fit naturally in OTP
- Phoenix gives us a fast path to APIs, LiveView, PubSub, and operator tooling

### Negative

- the codebase will become polyglot
- we must protect semantic consistency between Python and Elixir carefully
- we add build, CI, and architectural complexity

### Follow-on Decisions

- Python remains the semantic reference implementation until parity is proven
- Phoenix is the delivery and operator platform, not the home of pure deterministic semantics
- the migration should be incremental, not a big-bang rewrite
