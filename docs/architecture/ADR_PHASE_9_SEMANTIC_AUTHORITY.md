# ADR: Keep Python as the Long-Term Semantic Authority After Phase 9

## Status

Accepted

## Date

2026-03-07

## Context

By the end of Phase 8, DecisionGraph already had:

- a BEAM event store
- a supervised projection runtime
- authenticated service APIs
- a LiveView operator console
- workflow and review operations
- self-hosted install, recovery, and release guidance

Phase 9 existed to answer a narrower question:

- should semantic authority now move fully into Elixir, or
- should Python remain the semantic oracle while BEAM continues as the runtime platform

The Phase 9 parity work found no observed frozen-core drift across BEAM write, projection, query, and replay evidence for the frozen Phase 1 scope.

That result made a handoff possible in theory, but it did not make it necessary in practice.

## Decision

DecisionGraph will keep Python as the long-term semantic authority for the frozen Phase 1 reference scope.

This means:

- Python remains the canonical source for frozen-core semantic behavior
- the fixture bundle and reference docs remain Python-led release gates
- BEAM remains the runtime and product delivery layer for the self-hosted platform
- BEAM-only workflow and operator-era extensions remain product-owned on the BEAM side without pretending they replace the frozen reference scope
- no full semantic rewrite is required as a success condition

The project is therefore closing Phase 9 with a deliberate no-handoff outcome.

## Rationale

### 1. The BEAM platform already achieved the product goal

The strongest reason to move to BEAM was runtime ambition:

- supervision
- replay orchestration
- shared service APIs
- operator tooling
- self-hosted operational credibility

Those gains are already realized without replacing Python as the oracle.

### 2. Parity succeeded, but handoff did not create enough additional value

The parity report is strong enough to trust the BEAM runtime.
It is not a reason by itself to create migration and governance cost when the local-first product still benefits from an independent reference implementation.

### 3. Python still has real product value

Python continues to provide:

- the embedded library story
- SQLite-backed local operation
- offline and single-process usability
- the local CLI and reference harness

Those are not accidental leftovers.
They are still part of the product's value.

### 4. An independent oracle remains useful

Keeping Python authoritative preserves a clean parity oracle that is not coupled to the service runtime.
That discipline lowers the risk of future semantic drift going unnoticed.

## Consequences

### Positive

- the project keeps a stable local and reference mode
- the BEAM platform remains fully justified without forcing a semantic rewrite
- the parity oracle stays independent from the runtime implementation
- future semantic changes stay disciplined because they must cross both the reference and parity gates

### Negative

- some pure logic remains mirrored across Python and Elixir
- maintainers must continue to care about parity upkeep
- future contributors must respect the difference between runtime ownership and semantic ownership

## What This Does Not Mean

This decision does not mean:

- the BEAM platform is incomplete
- Elixir parity is weak
- semantic ports were a mistake

It means the project reached a stable architecture where:

- Python is the oracle
- BEAM is the platform

## Revisit Rule

This ADR may be replaced only by a new ADR that shows:

- materially different product constraints
- refreshed parity evidence
- an explicit Python compatibility story
- explicit rollback and governance approval

Until that happens, Python remains the semantic authority.
