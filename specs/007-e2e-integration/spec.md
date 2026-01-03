# Feature Specification: End-to-End Integration & Documentation

**Feature Branch**: `007-e2e-integration`
**Created**: 2026-01-01
**Status**: Draft
**SSOT Phase**: P6 — E2E Fixtures + Documentation + Optional CLI
**SSOT Reference**: `SPEC_v1.0.3-minpatch.md` Section 8.1 (P6)

## Overview

This specification covers end-to-end testing with golden fixtures based on the three scenarios in SSOT Section 10, minimal documentation, and an optional CLI for replay/inspection. This phase validates that all components work together correctly.

**SSOT Principle**: E2E scenarios are defined in SSOT Section 10. Golden fixtures MUST match those examples exactly.

---

## Constitution Check

| Principle | Applies | How Verified |
|-----------|---------|--------------|
| I. Append-Only SSOT | ✅ | Fixtures are immutable events |
| II. Deterministic Replay | ✅ | Golden digest matching |
| III. Library-First | ✅ | CLI optional, read-only only |
| IV. Minimal Dependencies | ✅ | No additional deps for fixtures |
| V. Module Boundaries | ✅ | testing/ module isolated |
| VI. Framework-Agnostic | ✅ | Framework-independent fixtures |

**Key Constraints**:
- Fixtures MUST replay with identical digests (Constitution II, DD-013)
- CLI (if implemented) MUST be read-only (Constitution III)
- No Chain-of-Thought content in fixtures (SSOT 13)
- README examples MUST be executable without errors (Constitution III)

---

## User Scenarios & Testing

### User Story 1 - Golden Fixture Validation (Priority: P1)

As a CI operator, I want golden fixtures so that regressions are caught automatically.

**Why this priority**: Golden tests ensure determinism across releases.

**Independent Test**: Can be verified by running fixture replay and comparing digest.

**Acceptance Scenarios**:

1. **Given** Renewal scenario fixture, **When** replayed, **Then** digest matches expected value
2. **Given** Support Escalation fixture, **When** replayed, **Then** digest matches expected value
3. **Given** Deal Desk fixture, **When** replayed, **Then** digest matches expected value

---

### User Story 2 - E2E Query Verification (Priority: P1)

As a test author, I want query assertions on fixtures so that query behavior is validated.

**Why this priority**: Queries are the user-facing interface.

**Independent Test**: Can be verified by running queries on fixtures and comparing to expected results.

**Acceptance Scenarios**:

1. **Given** Renewal fixture, **When** I query `get_trace_events`, **Then** 9 events returned in correct order
2. **Given** fixture with precedent citation, **When** I query `find_precedents`, **Then** cited trace found
3. **Given** fixture, **When** I query `get_context_subgraph`, **Then** expected nodes/edges returned

---

### User Story 3 - Documentation Accuracy (Priority: P1)

As a new user, I want accurate README examples so that I can onboard quickly.

**Why this priority**: Documentation is first impression.

**Independent Test**: Can be verified by running README code snippets.

**Acceptance Scenarios**:

1. **Given** README code examples, **When** executed, **Then** they run without errors
2. **Given** README, **When** checked against SPEC, **Then** no contradictions exist
3. **Given** any external link in SPEC, **Then** it should not exist (SPEC is SSOT)

---

### User Story 4 - Optional CLI for Debugging (Priority: P3)

As a developer debugging issues, I want a CLI tool so that I can inspect traces and replay projections.

**Why this priority**: Developer experience (optional, not critical path).

**Independent Test**: Can be verified by running CLI commands.

**Acceptance Scenarios**:

1. **Given** `python -m decisiongraph replay`, **When** run, **Then** projections rebuilt and digest printed
2. **Given** `python -m decisiongraph dump-trace <id>`, **When** run, **Then** trace events printed
3. **Given** CLI, **When** executed, **Then** all operations are read-only

---

### Edge Cases

- What happens when fixture file is missing? → Clear error message
- What happens when fixture has wrong format? → Validation error before replay
- What happens when CLI is run without database? → Helpful error message

---

## Requirements

### Functional Requirements

- **FR-001**: Three scenarios MUST exist → SSOT 10.1, 10.2, 10.3
- **FR-002**: Fixtures MUST include event JSONs → SSOT 10
- **FR-003**: Fixtures MUST include expected graph digest → SSOT 6.2.7
- **FR-004**: Full replay MUST match expected digest → SSOT DD-013
- **FR-005**: Query results MUST match expected outputs → SSOT 10
- **FR-006**: CLI (if implemented) MUST be read-only → SSOT 8.1 P6
- **FR-007**: README MUST be consistent with SPEC → SSOT 13
- **FR-008**: No external links in SPEC → SSOT 13

### Golden Fixtures (from SSOT Section 10)

1. **Scenario A: Renewal Agent** (SSOT 10.1)
   - 20% discount with exception + Finance approval
   - 9 events: TraceStarted → EntityObserved → InputObserved → PolicyEvaluated → PrecedentCited → ExceptionRequested → ApprovalRecorded → ActionCommitted → TraceFinished

2. **Scenario B: Support Escalation** (SSOT 10.2)
   - Cross-system synthesis → Tier 3 escalation
   - ARR from CRM, escalations from Zendesk, churn-risk flag

3. **Scenario C: Deal Desk** (SSOT 10.3)
   - Healthcare extra discount (tribal knowledge made explicit)
   - Exception with PrecedentCited

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: All 3 fixtures replay successfully
- **SC-002**: Digests match expected values 100%
- **SC-003**: Query assertions pass for all fixtures
- **SC-004**: All 10 test cases from SSOT P6 pass (TC-P6-001 through TC-P6-010)
- **SC-005**: README examples execute without errors
- **SC-006**: No chain-of-thought content in fixtures

### Test Cases (from SSOT 8.1)

| ID | Name | Description |
|----|------|-------------|
| TC-P6-001 | fixture_renewal_digest | Renewal scenario digest matches |
| TC-P6-002 | fixture_renewal_queries | Renewal queries return expected |
| TC-P6-003 | fixture_support_digest | Support scenario digest matches |
| TC-P6-004 | fixture_support_queries | Support queries return expected |
| TC-P6-005 | fixture_dealdesk_digest | Deal Desk digest matches |
| TC-P6-006 | fixture_dealdesk_queries | Deal Desk queries return expected |
| TC-P6-007 | cli_replay_outputs_digest | CLI replay prints correct digest |
| TC-P6-008 | cli_dump_trace_stable | CLI dump is deterministic |
| TC-P6-009 | docs_examples_compile | README examples run |
| TC-P6-010 | no_chain_of_thought | No CoT in fixtures |

---

## Dependencies & Constraints

### Depends On

- **All previous phases**: 001-006 must be complete

### Blocks

- None (final phase)

---

## Files to Implement

```
src/decisiongraph/
  testing/
    golden.py            # Fixture loading/validation utilities
  __main__.py            # Optional CLI entry point
tests/
  golden/
    renewal/
      events.json        # Event fixture from SSOT 10.1
      expected_digest.txt
    support/
      events.json
      expected_digest.txt
    dealdesk/
      events.json
      expected_digest.txt
  e2e/
    test_fixtures.py     # TC-P6-001 through TC-P6-006
    test_cli.py          # TC-P6-007, TC-P6-008
    test_docs.py         # TC-P6-009, TC-P6-010
README.md                # Minimal usage documentation
LICENSE                  # Apache-2.0
```

---

## SSOT References

- Section 10: End-to-End Examples
- Section 10.1: Renewal Agent scenario
- Section 10.2: Support Escalation scenario
- Section 10.3: Deal Desk scenario
- Section 13: Consistency Gate (no CoT, no external links)
- DD-013: Replay digest gate
