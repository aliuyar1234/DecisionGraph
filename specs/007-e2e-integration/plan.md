# Implementation Plan: E2E Integration & Documentation

**Branch**: `007-e2e-integration` | **Date**: 2026-01-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/007-e2e-integration/spec.md`
**SSOT Phase**: P6 — E2E Fixtures + Documentation + Optional CLI

## Summary

Implement end-to-end testing with golden fixtures based on the three scenarios in SSOT Section 10, minimal documentation, and an optional CLI for replay/inspection. This phase validates that all components work together correctly.

## Technical Context

**Language/Version**: Python 3.12+ (DD-003)
**Primary Dependencies**: None (stdlib only)
**Storage**: SQLite for fixtures
**Testing**: pytest with golden fixtures
**Target Platform**: Cross-platform
**Project Type**: Single project with src-layout
**Performance Goals**: All fixtures replay in <10s
**Constraints**: No Chain-of-Thought in fixtures, CLI read-only
**Scale/Scope**: 3 scenarios, README, optional CLI

## Constitution Check

*GATE: All checks pass - no violations*

| Principle | Status | Verification |
|-----------|--------|--------------|
| I. Append-Only SSOT | ✅ | Fixtures are immutable events |
| II. Deterministic Replay | ✅ | Golden digest matching |
| III. Library-First | ✅ | CLI optional, read-only only |
| IV. Minimal Dependencies | ✅ | No additional deps for fixtures |
| V. Module Boundaries | ✅ | testing/ module isolated |
| VI. Framework-Agnostic | ✅ | Framework-independent fixtures |

## Project Structure

### Source Code

```text
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

## Implementation Steps

### Phase 1: Golden Fixture Format

1. Define JSON format for fixtures:
   ```json
   {
     "scenario": "renewal",
     "description": "...",
     "events": [...],
     "expected_digest": "sha256:..."
   }
   ```

2. Implement `testing/golden.py`:
   - `load_fixture(path) -> list[EventEnvelope]`
   - `replay_fixture(store, events) -> str` (returns digest)
   - `validate_fixture(path) -> bool`

### Phase 2: Create Fixtures

1. Create `tests/golden/renewal/events.json`:
   - 9 events from SSOT 10.1
   - TraceStarted → EntityObserved → InputObserved → PolicyEvaluated → PrecedentCited → ExceptionRequested → ApprovalRecorded → ActionCommitted → TraceFinished

2. Create `tests/golden/support/events.json`:
   - Support Escalation scenario from SSOT 10.2

3. Create `tests/golden/dealdesk/events.json`:
   - Deal Desk scenario from SSOT 10.3

### Phase 3: E2E Tests

1. Implement `test_fixtures.py`:
   - TC-P6-001: fixture_renewal_digest
   - TC-P6-002: fixture_renewal_queries
   - TC-P6-003: fixture_support_digest
   - TC-P6-004: fixture_support_queries
   - TC-P6-005: fixture_dealdesk_digest
   - TC-P6-006: fixture_dealdesk_queries

### Phase 4: Optional CLI

1. Implement `__main__.py`:
   - `python -m decisiongraph replay <db>` → Rebuild projections, print digest
   - `python -m decisiongraph dump-trace <db> <trace_id>` → Print events
   - Read-only operations only

2. Implement `test_cli.py`:
   - TC-P6-007: cli_replay_outputs_digest
   - TC-P6-008: cli_dump_trace_stable

### Phase 5: Documentation

1. Update `README.md`:
   - Installation instructions
   - Basic usage examples
   - API overview

2. Implement `test_docs.py`:
   - TC-P6-009: docs_examples_compile
   - TC-P6-010: no_chain_of_thought

### Phase 6: Final Validation

1. Run all 10 P6 test cases
2. Verify digests match expected values
3. Verify no Chain-of-Thought content

## SSOT References

- Section 10: End-to-End Examples
- Section 10.1: Renewal Agent scenario
- Section 10.2: Support Escalation scenario
- Section 10.3: Deal Desk scenario
- Section 13: Consistency Gate
- DD-013: Replay digest gate
