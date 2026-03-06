# ADR: Phoenix Is the Platform Delivery and Operator Layer

## Status

Accepted

## Date

2026-03-06

## Context

The future DecisionGraph product needs:

- service APIs for ingestion and reads
- realtime operator interfaces
- replay and health management surfaces
- collaborative workflows for approvals and investigations
- a practical path to sockets, PubSub, and live dashboards

Phoenix is a strong fit for those requirements, but there is a common BEAM anti-pattern of using processes or framework layers as substitutes for normal domain design.

We need a clear boundary for what Phoenix should and should not own.

## Decision

Phoenix will serve as the platform delivery layer for DecisionGraph.

Phoenix will own:

- JSON and HTTP APIs
- operator-facing web experience
- Phoenix LiveView interfaces
- realtime subscriptions, PubSub integration, and optional Channels
- authentication and session handling
- tenant-aware delivery boundaries

Phoenix will not be the primary home for:

- pure deterministic event semantics
- canonicalization logic
- replay invariants
- digest rules
- domain validation rules that should remain framework-independent

Those belong in domain-oriented Elixir modules and, during the transition, remain anchored to the Python reference semantics.

## Rationale

Phoenix gives DecisionGraph a path to become a serious product quickly:

- LiveView is a strong fit for an operator console
- PubSub makes worker state and projection status easy to surface live
- Phoenix controllers and routers give us a disciplined external API layer
- Presence can later support collaborative investigation and approval flows

Keeping Phoenix out of the pure semantic core preserves testability and prevents framework lock-in from contaminating the most correctness-sensitive logic.

## Consequences

### Positive

- the project can evolve into a premium operator-grade product
- delivery concerns and domain semantics stay meaningfully separated
- realtime features become natural instead of bolted on

### Negative

- we must maintain boundary discipline
- there will be some duplication between UI needs and lower-level services if boundaries are weakly enforced
- the Phoenix layer will need careful authorization design because it will expose sensitive control surfaces

## Implementation Guidance

- keep controllers thin
- use LiveView for operator-centric surfaces before building a SPA
- use PubSub as a core primitive for replay, health, and workflow updates
- delay Channels until non-browser realtime consumers justify them
- keep deterministic business logic in plain modules, not GenServers just for organization
