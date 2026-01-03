# Implementation Plan: Event Model & Serialization

**Branch**: `002-event-model` | **Date**: 2026-01-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-event-model/spec.md`
**SSOT Phase**: P1 — Event Model + Canonical Serialization + InMemory Store

## Summary

Implement the event model with 10 event types, canonical JSON serialization for deterministic hashing, idempotency handling, and an in-memory event store for testing. This phase establishes the append-only event log semantics that are core to DecisionGraph.

## Technical Context

**Language/Version**: Python 3.12+ (DD-003)
**Primary Dependencies**: None for core (stdlib json per DD-008)
**Storage**: InMemoryEventStore (for testing)
**Testing**: pytest
**Target Platform**: Cross-platform (Python stdlib)
**Project Type**: Single project with src-layout
**Performance Goals**: Canonical JSON in <1ms, hash in <1ms
**Constraints**: No floats in JSON (DD-008), PII guard enforcement
**Scale/Scope**: 10 event types, idempotency, trace sequence

## Constitution Check

*GATE: All checks pass - no violations*

| Principle | Status | Verification |
|-----------|--------|--------------|
| I. Append-Only SSOT | ✅ | Events immutable after storage (DD-009) |
| II. Deterministic Replay | ✅ | Canonical JSON produces identical hashes |
| III. Library-First | ✅ | InMemoryStore for testing without DB |
| IV. Minimal Dependencies | ✅ | stdlib JSON serialization (DD-008) |
| V. Module Boundaries | ✅ | serialization/ independent of storage/ |
| VI. Framework-Agnostic | ✅ | Generic EventStore protocol |

## Project Structure

### Documentation (this feature)

```text
specs/002-event-model/
├── spec.md
├── plan.md              # This file
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
└── checklists/
```

### Source Code (repository root)

```text
src/decisiongraph/
  serialization/
    canonical_json.py    # canonicalize_json() per SSOT 6.1.5
    hashing.py           # sha256_hex, sha256_prefixed
  domain/
    events.py            # EventEnvelope, StoredEvent (SSOT 11.3)
    validation.py        # Payload validation, PII guard
  storage/
    interface.py         # EventStore protocol (SSOT 11.6)
  testing/
    fakes.py             # InMemoryEventStore
  api.py                 # Emission methods (start_trace, etc.)

tests/
  unit/
    test_canonical_json.py
    test_event_model.py
    test_inmemory_store.py
    test_pii_guard.py
```

**Structure Decision**: Extends 001-foundation structure per SSOT 5.2

## Implementation Steps

### Phase 1: Canonical Serialization

1. Implement `canonical_json.py`:
   - `canonicalize_json(obj)` → sorted keys, no whitespace, no floats
   - Reject floats at any nesting depth
   - UTF-8 encoding

2. Implement `hashing.py`:
   - `sha256_hex(data: bytes) -> str`
   - `sha256_prefixed(data: bytes) -> str` → "sha256:..."

### Phase 2: Event Model

1. Implement `domain/events.py`:
   - `EventEnvelope` dataclass (all fields except log_seq)
   - `StoredEvent` dataclass (includes log_seq, recorded_at)
   - 10 event type payloads

2. Implement `domain/validation.py`:
   - Schema validation per event type
   - PII guard (forbidden substrings)

### Phase 3: Storage Interface

1. Implement `storage/interface.py`:
   - `EventStore` protocol
   - `append_event(envelope) -> StoredEvent`
   - `get_trace_events(trace_id) -> list[StoredEvent]`
   - `list_events(filter) -> list[StoredEvent]`
   - `get_last_log_seq() -> int`

2. Implement `testing/fakes.py`:
   - `InMemoryEventStore` implementing protocol
   - Idempotency via dict lookup
   - trace_seq enforcement

### Phase 4: Emission API

1. Implement emission methods in `api.py`:
   - `start_trace()` → TraceStarted
   - `observe_input()` → InputObserved
   - `observe_entity()` → EntityObserved
   - `evaluate_policy()` → PolicyEvaluated
   - `request_exception()` → ExceptionRequested
   - `record_approval()` → ApprovalRecorded
   - `cite_precedent()` → PrecedentCited
   - `propose_action()` → ActionProposed
   - `commit_action()` → ActionCommitted
   - `finish_trace()` → TraceFinished

### Phase 5: Tests

1. TC-P1-001 through TC-P1-011
2. PII guard rejection tests
3. Idempotency tests

## SSOT References

- Section 2.1: Decision Trace invariants
- Section 6.1.1: Event Envelope schema
- Section 6.1.2: Event Types
- Section 6.1.3: Payload Schemas
- Section 6.1.5: Canonical Serialization
- Section 6.1.7: Idempotency Keys
- Section 6.1.8.1: PII Guard
- Section 11.3: domain/events.py skeleton
- Section 11.6: storage/interface.py skeleton
