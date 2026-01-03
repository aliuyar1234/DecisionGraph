# Implementation Plan: DecisionGraph Foundation

**Branch**: `001-foundation` | **Date**: 2026-01-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-foundation/spec.md`
**SSOT Phase**: P0 — Repo Bootstrap + Contracts

## Summary

Establish the foundational repository structure, build configuration, error handling, and domain type stubs for DecisionGraph. This phase creates the architectural contracts and module boundaries that all subsequent phases depend upon.

## Technical Context

**Language/Version**: Python 3.12+ (DD-003)
**Primary Dependencies**: None for core (stdlib only per DD-004)
**Storage**: N/A (stubs only in this phase)
**Testing**: pytest
**Target Platform**: Cross-platform (Python stdlib)
**Project Type**: Single project with src-layout
**Performance Goals**: Import in <1s, installation in <30s
**Constraints**: No external runtime dependencies for core module
**Scale/Scope**: Foundation for 7-phase implementation

## Constitution Check

*GATE: All checks pass - no violations*

| Principle | Status | Verification |
|-----------|--------|--------------|
| I. Append-Only SSOT | N/A | No data operations in this phase |
| II. Deterministic Replay | N/A | No projections in this phase |
| III. Library-First | ✅ | Package installable without services |
| IV. Minimal Dependencies | ✅ | stdlib dataclasses only (DD-004) |
| V. Module Boundaries | ✅ | import-linter configured (DD-014) |
| VI. Framework-Agnostic | ✅ | No framework dependencies |

## Project Structure

### Documentation (this feature)

```text
specs/001-foundation/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Research findings
├── data-model.md        # Domain entities
├── quickstart.md        # Getting started guide
├── contracts/           # API contracts
└── checklists/
    └── requirements.md  # Quality checklist
```

### Source Code (repository root)

```text
src/
  decisiongraph/
    __init__.py          # Package root, exposes __version__
    api.py               # Stub for high-level API
    errors.py            # DecisionGraphError + error codes
    ids.py               # ID generation utilities
    time.py              # Time utilities
    domain/
      __init__.py
      types.py           # All domain dataclasses (SSOT 11.2)
      events.py          # EventEnvelope, StoredEvent stubs
      validation.py      # Stub
    serialization/
      __init__.py
      canonical_json.py  # Stub
      hashing.py         # sha256_hex, sha256_prefixed
    storage/
      __init__.py
      interface.py       # Stub
    projections/
      __init__.py
      interfaces.py      # Stub
    query/
      __init__.py
      filters.py         # Stub
      events.py          # Stub
      graph.py           # Stub
      precedents.py      # Stub
    policy/
      __init__.py
      interfaces.py      # Stub
    testing/
      __init__.py
      fakes.py           # Stub
      golden.py          # Stub

tests/
  unit/
    test_bootstrap.py    # TC-P0-001 through TC-P0-010

pyproject.toml
importlinter.ini
LICENSE                  # Apache-2.0
README.md
```

**Structure Decision**: src-layout per DD-003 with module structure per SSOT 5.2

## Complexity Tracking

> No violations - all requirements align with constitution

## Implementation Steps

### Phase 1: Repository Setup

1. Create `pyproject.toml` with Python 3.12+ requirement
2. Create `LICENSE` (Apache-2.0 per DD-002)
3. Create `importlinter.ini` with module contracts (SSOT 5.3)
4. Create `README.md` with minimal usage

### Phase 2: Core Module Stubs

1. Create package structure under `src/decisiongraph/`
2. Implement `errors.py` with `DecisionGraphError` and error codes (SSOT 7.2)
3. Implement `ids.py` with UUID generation utilities
4. Implement `time.py` with RFC3339 utilities
5. Implement `domain/types.py` with all dataclasses (SSOT 11.2)

### Phase 3: Verification

1. Create `tests/unit/test_bootstrap.py` with TC-P0-001 through TC-P0-010
2. Verify `pip install -e .` works
3. Verify `import decisiongraph` succeeds
4. Verify mypy strict passes
5. Verify import-linter passes

## SSOT References

- Section 5: Modular Repo Design
- Section 7.2: Error Codes
- Section 8.1: P0 Phase Definition
- Section 11.1: errors.py skeleton
- Section 11.2: domain/types.py skeleton
