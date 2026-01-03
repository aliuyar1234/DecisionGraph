# Feature Specification: Event Model & Serialization

**Feature Branch**: `002-event-model`
**Created**: 2026-01-01
**Status**: Draft
**SSOT Phase**: P1 — Event Model + Canonical Serialization + InMemory Store
**SSOT Reference**: `SPEC_v1.0.3-minpatch.md` Section 8.1 (P1)

## Overview

This specification covers the event model, canonical serialization, and in-memory storage backend for unit testing. This phase implements the append-only event log semantics, idempotency handling, and the complete event schema as defined in the SSOT.

**SSOT Principle**: Event schemas, payload structures, and serialization rules are defined in SSOT Sections 6.1 and 11. This spec references those sections.

---

## Constitution Check

| Principle | Applies | How Verified |
|-----------|---------|--------------|
| I. Append-Only SSOT | ✅ | Events immutable after storage (DD-009) |
| II. Deterministic Replay | ✅ | Canonical JSON produces identical hashes |
| III. Library-First | ✅ | InMemoryStore for testing without DB |
| IV. Minimal Dependencies | ✅ | stdlib JSON serialization (DD-008) |
| V. Module Boundaries | ✅ | serialization/ independent of storage/ |
| VI. Framework-Agnostic | ✅ | Generic EventStore protocol |

**Key Constraints**:
- Events MUST NOT be mutated after `append_event()` (Constitution I)
- Canonical JSON MUST be deterministic (Constitution II)
- Serialization MUST use stdlib JSON only (Constitution IV)
- `recorded_at` set by backend, not caller (Constitution II - no wall-clock in caller)

---

## User Scenarios & Testing

### User Story 1 - Emit Decision Trace Events (Priority: P1)

As a workflow developer, I want to emit decision trace events so that decisions are recorded in the append-only log.

**Why this priority**: Core functionality - without event emission, no decision traces can be created.

**Independent Test**: Can be verified by calling `start_trace()` and checking that a `TraceStarted` event is stored.

**Acceptance Scenarios**:

1. **Given** a DecisionGraph instance, **When** I call `start_trace()` with valid parameters, **Then** a `TraceStarted` event is appended with `trace_seq=0`
2. **Given** an active trace, **When** I call `observe_input()`, **Then** an `InputObserved` event is appended with incrementing `trace_seq`
3. **Given** an active trace, **When** I call `finish_trace()`, **Then** a `TraceFinished` event is appended and trace is locked

---

### User Story 2 - Canonical JSON Serialization (Priority: P1)

As a system integrator, I want deterministic JSON serialization so that payload hashes are reproducible across systems.

**Why this priority**: Hash stability is required for replay determinism and integrity verification.

**Independent Test**: Can be verified by serializing the same object multiple times and comparing outputs.

**Acceptance Scenarios**:

1. **Given** a dict with unordered keys, **When** I call `canonicalize_json()`, **Then** keys are sorted lexicographically
2. **Given** any valid payload, **When** serialized twice, **Then** output strings are byte-identical
3. **Given** a payload containing a float, **When** I attempt serialization, **Then** `DG_ERR_SCHEMA_VIOLATION` is raised

---

### User Story 3 - Idempotency Handling (Priority: P1)

As a resilient system operator, I want idempotent event emission so that retries don't create duplicate events.

**Why this priority**: At-least-once delivery requires idempotency for correctness.

**Independent Test**: Can be verified by emitting the same event twice with same idempotency key.

**Acceptance Scenarios**:

1. **Given** an event with idempotency_key "X", **When** I emit the same event again with key "X", **Then** the original `event_id` and `log_seq` are returned (idempotent success)
2. **Given** an event with idempotency_key "X", **When** I emit a different payload with key "X", **Then** `DG_ERR_IDEMPOTENCY_CONFLICT` is raised
3. **Given** idempotency scope is `(producer_id, idempotency_key)`, **When** different producers use same key, **Then** both events are stored (no conflict)

---

### User Story 4 - Trace Sequence Enforcement (Priority: P1)

As a data integrity guardian, I want trace_seq to be strictly monotonic so that event ordering is unambiguous.

**Why this priority**: Replay correctness depends on deterministic event ordering within traces.

**Independent Test**: Can be verified by checking trace_seq values after multiple emissions.

**Acceptance Scenarios**:

1. **Given** an active trace at `trace_seq=N`, **When** next event is appended, **Then** `trace_seq=N+1`
2. **Given** a trace, **When** I attempt to append with wrong trace_seq, **Then** `DG_ERR_EVENT_SEQUENCE_INVALID` is raised
3. **Given** a finished trace, **When** I attempt to append another event, **Then** `DG_ERR_EVENT_SEQUENCE_INVALID` is raised

---

### User Story 5 - PII/Secret Guard (Priority: P1)

As a compliance officer, I want forbidden content to be rejected so that secrets don't leak into the event log.

**Why this priority**: Security baseline - prevents accidental credential storage.

**Independent Test**: Can be verified by attempting to store a payload containing "Bearer ".

**Acceptance Scenarios**:

1. **Given** a payload containing "Bearer ", **When** I attempt to emit, **Then** `DG_ERR_PII_POLICY_VIOLATION` is raised
2. **Given** a payload containing "xoxb-", **When** I attempt to emit, **Then** `DG_ERR_PII_POLICY_VIOLATION` is raised
3. **Given** a payload containing "-----BEGIN", **When** I attempt to emit, **Then** `DG_ERR_PII_POLICY_VIOLATION` is raised
4. **Given** a clean payload, **When** I emit, **Then** event is stored successfully

---

### User Story 6 - InMemory Store for Testing (Priority: P2)

As a test author, I want an in-memory event store so that unit tests don't require a database.

**Why this priority**: Enables fast, isolated unit testing.

**Independent Test**: Can be verified by running tests with `InMemoryEventStore` without any database setup.

**Acceptance Scenarios**:

1. **Given** InMemoryEventStore, **When** I append events, **Then** they are retrievable via `get_trace_events()`
2. **Given** InMemoryEventStore, **When** I call `list_events()`, **Then** events are ordered by `log_seq`
3. **Given** InMemoryEventStore, **When** I call `get_last_log_seq()`, **Then** current max log_seq is returned

---

### Edge Cases

- What happens when `occurred_at` is not provided? → Backend sets `occurred_at` to commit time
- What happens when `recorded_at` is in envelope? → Ignored; backend always sets `recorded_at`
- What happens when payload contains nested floats? → Rejected at any depth
- What happens when idempotency_key exceeds 200 bytes? → `DG_ERR_INVALID_ARGUMENT`

---

## Requirements

### Functional Requirements

- **FR-001**: Canonical JSON MUST follow rules in → SSOT 6.1.5
- **FR-002**: `payload_hash` MUST be `sha256:<hex>` over canonical payload → SSOT 6.1.5
- **FR-003**: Event envelope MUST contain all fields from → SSOT 6.1.1
- **FR-004**: Event types MUST be exactly the 10 types in → SSOT 6.1.2
- **FR-005**: Payload schemas MUST match → SSOT 6.1.3
- **FR-006**: Idempotency scope MUST be `(producer_id, idempotency_key)` → SSOT 6.1.7
- **FR-007**: `trace_seq` MUST start at 0 and increment by 1 → SSOT 2.1
- **FR-008**: `TraceFinished` MUST lock trace for further appends → SSOT 2.1
- **FR-009**: PII guard MUST scan for forbidden substrings → SSOT 6.1.8.1
- **FR-010**: Floats MUST be rejected in payloads → SSOT 6.1.5
- **FR-011**: `EventStore.append_event()` MUST return `StoredEvent` → SSOT DD-020
- **FR-012**: `recorded_at` MUST be set by backend at commit time → SSOT DD-020

### Key Entities

All entity definitions are in SSOT Sections 6.1 and 11.3:

- **EventEnvelope**: Pre-storage event with all fields except `log_seq` (SSOT 11.3)
- **StoredEvent**: Persisted event including `log_seq` and `recorded_at` (SSOT 11.3)
- **SourceRef**: Producer identification (producer_id, system, subsystem)
- **EventStore Protocol**: Interface for append/query operations (SSOT 11.6)

### Event Types (SSOT 6.1.2)

1. TraceStarted
2. InputObserved
3. EntityObserved
4. PolicyEvaluated
5. ExceptionRequested
6. ApprovalRecorded
7. PrecedentCited
8. ActionProposed
9. ActionCommitted
10. TraceFinished

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: Canonical JSON produces identical output for identical input 100% of the time
- **SC-002**: Hash verification passes for all stored events
- **SC-003**: Idempotent retries return within 10ms (in-memory)
- **SC-004**: All 11 test cases from SSOT P1 pass (TC-P1-001 through TC-P1-011)
- **SC-005**: Unit tests run without any external dependencies (no database)

### Test Cases (from SSOT 8.1)

| ID | Name | Description |
|----|------|-------------|
| TC-P1-001 | canonical_json_key_order | Keys sorted lexicographically |
| TC-P1-002 | canonical_json_no_whitespace | No extra whitespace in output |
| TC-P1-003 | hash_matches | payload_hash matches recomputed hash |
| TC-P1-004 | reject_float | Floats in payload rejected |
| TC-P1-005 | idempotency_repeat_success | Duplicate emit returns same IDs |
| TC-P1-006 | idempotency_conflict_error | Different payload with same key errors |
| TC-P1-007 | trace_seq_monotonic_enforced | trace_seq increments by 1 |
| TC-P1-008 | trace_finish_locks | No appends after TraceFinished |
| TC-P1-009 | append_returns_log_seq | append_event returns StoredEvent |
| TC-P1-010 | get_trace_events_ordered | Events ordered by trace_seq |
| TC-P1-011 | pii_guard_rejects | Forbidden substrings rejected |

---

## Dependencies & Constraints

### Depends On

- **001-foundation**: Domain types, error codes, module structure

### Blocks

- 003-storage-sqlite (P2)
- All subsequent phases

### Frozen Decisions (from SSOT Section 4)

- **DD-008**: Canonical JSON + SHA-256 hashing
- **DD-009**: Append-only event log as SSOT
- **DD-020**: append_event returns StoredEvent

---

## Files to Implement

```
src/decisiongraph/
  serialization/
    canonical_json.py    # Implement canonicalize_json() per SSOT 6.1.5
    hashing.py           # Already has sha256_hex/sha256_prefixed
  domain/
    events.py            # Implement EventEnvelope, StoredEvent (SSOT 11.3)
    validation.py        # Implement payload validation, PII guard
  storage/
    interface.py         # Implement EventStore protocol (SSOT 11.6)
  testing/
    fakes.py             # Implement InMemoryEventStore
  api.py                 # Implement emission methods (start_trace, etc.)
tests/
  unit/
    test_canonical_json.py
    test_event_model.py
    test_inmemory_store.py
    test_pii_guard.py
```

---

## SSOT References

- Section 2.1: Decision Trace invariants
- Section 2.2: TraceEvent definition
- Section 6.1.1: Event Envelope schema
- Section 6.1.2: Event Types
- Section 6.1.3: Payload Schemas
- Section 6.1.5: Canonical Serialization
- Section 6.1.7: Idempotency Keys
- Section 6.1.8.1: PII Guard
- Section 11.3: domain/events.py skeleton
- Section 11.6: storage/interface.py skeleton
- DD-008, DD-009, DD-020: Frozen decisions
