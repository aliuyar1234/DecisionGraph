# Feature Specification: DecisionGraph Foundation

**Feature Branch**: `001-foundation`
**Created**: 2026-01-01
**Status**: Draft
**SSOT Phase**: P0 — Repo Bootstrap + Contracts
**SSOT Reference**: `SPEC_v1.0.3-minpatch.md` Section 8.1 (P0)

## Overview

This specification covers the foundational setup of the DecisionGraph project: repository structure, build configuration, error handling, and domain type stubs. This phase establishes the architectural contracts and module boundaries that all subsequent phases depend upon.

**SSOT Principle**: All technical details (schemas, signatures, constraints) are defined in SSOT Section 5 and 11. This spec references those sections rather than duplicating them.

---

## Constitution Check

| Principle | Applies | How Verified |
|-----------|---------|--------------|
| I. Append-Only SSOT | Setup only | N/A (no data operations) |
| II. Deterministic Replay | Setup only | N/A (no projections) |
| III. Library-First | ✅ | Package installable without services |
| IV. Minimal Dependencies | ✅ | stdlib dataclasses only (DD-004) |
| V. Module Boundaries | ✅ | import-linter configured (DD-014) |
| VI. Framework-Agnostic | ✅ | No framework dependencies in core |

**Key Constraints**:
- Domain types MUST use `dataclasses`, NOT pydantic/attrs (Constitution IV)
- Module boundaries MUST be enforced via import-linter (Constitution V)
- No external dependencies for core module (Constitution IV)

---

## User Scenarios & Testing

### User Story 1 - Package Installation (Priority: P1)

As a developer integrating DecisionGraph, I want to install the package via pip so that I can use it in my project.

**Why this priority**: Without installable package, no other functionality can be accessed.

**Independent Test**: Can be fully tested by running `pip install -e .` in a fresh virtualenv and verifying import works.

**Acceptance Scenarios**:

1. **Given** a fresh Python 3.12+ virtualenv, **When** I run `pip install -e .`, **Then** installation completes without errors
2. **Given** installed package, **When** I run `python -c "import decisiongraph"`, **Then** import succeeds without errors
3. **Given** installed package, **When** I check `decisiongraph.__version__`, **Then** a version string is returned

---

### User Story 2 - Error Handling Contract (Priority: P1)

As a developer using DecisionGraph, I want structured error codes so that I can programmatically handle different failure modes.

**Why this priority**: Error handling is fundamental to all API operations.

**Independent Test**: Can be verified by catching `DecisionGraphError` and checking its `code` attribute.

**Acceptance Scenarios**:

1. **Given** any DecisionGraph operation fails, **When** I catch the exception, **Then** it is a `DecisionGraphError` with a `code` attribute
2. **Given** a `DecisionGraphError`, **When** I check its `code`, **Then** it matches one of the defined error codes (→ SSOT 7.2)
3. **Given** a `DecisionGraphError`, **When** I convert to string, **Then** format is `"{code}: {message}"`

---

### User Story 3 - Domain Types Available (Priority: P2)

As a developer building on DecisionGraph, I want type-safe domain primitives so that my IDE and type checker can validate my code.

**Why this priority**: Types enable compile-time correctness and documentation.

**Independent Test**: Can be verified by importing types and constructing instances with valid data.

**Acceptance Scenarios**:

1. **Given** I import from `decisiongraph.domain.types`, **When** I construct `ActorRef(actor_type="agent", actor_id="test")`, **Then** a valid instance is created
2. **Given** I run mypy in strict mode, **When** I use domain types correctly, **Then** no type errors are reported
3. **Given** I construct a `Value` with `type="decimal"`, **When** I provide `value="123.45"`, **Then** value is stored as string (no float)

---

### User Story 4 - Module Boundaries Enforced (Priority: P2)

As a project maintainer, I want module boundaries enforced in CI so that architectural violations are caught early.

**Why this priority**: Prevents spaghetti architecture as codebase grows.

**Independent Test**: Can be verified by running import-linter and checking exit code.

**Acceptance Scenarios**:

1. **Given** domain module, **When** I try to import from storage, **Then** import-linter fails
2. **Given** query module, **When** I try to import concrete backend (sqlite/postgres), **Then** import-linter fails
3. **Given** valid code respecting boundaries, **When** I run import-linter, **Then** all contracts pass

---

### User Story 5 - Type Checking Passes (Priority: P2)

As a contributor, I want mypy strict mode to pass so that type safety is enforced.

**Why this priority**: Type safety reduces runtime errors.

**Independent Test**: Run `mypy src/` with strict config and check exit code.

**Acceptance Scenarios**:

1. **Given** all source files, **When** I run mypy with strict mode, **Then** no errors are reported
2. **Given** domain dataclasses, **When** mypy analyzes them, **Then** all types are fully annotated

---

### Edge Cases

- What happens when Python version is < 3.12? → Installation SHOULD fail with clear error message
- What happens when optional dependencies are missing? → Core import MUST still succeed
- What happens when invalid actor_type is passed to ActorRef? → Type checker SHOULD flag error (Literal type)

---

## Requirements

### Functional Requirements

- **FR-001**: Package MUST follow src-layout (`src/decisiongraph/`) → SSOT 5.1
- **FR-002**: Package MUST expose `decisiongraph.__version__` → SSOT 8.1 (TC-P0-010)
- **FR-003**: `DecisionGraphError` MUST have `code` and `message` attributes → SSOT 11.1
- **FR-004**: Error codes MUST be from defined set → SSOT 7.2
- **FR-005**: Domain types MUST be stdlib dataclasses (no pydantic) → SSOT DD-004
- **FR-006**: Domain module MUST NOT import from storage/projections/query/api → SSOT 5.2
- **FR-007**: No circular imports MUST exist → SSOT 5.3
- **FR-008**: pyproject.toml MUST define Python 3.12+ requirement → SSOT DD-003
- **FR-009**: ruff + mypy + pytest + import-linter MUST be configured → SSOT 5.3, DD-014

### Key Entities

All entity definitions are in SSOT Section 11.2:

- **ActorRef**: Represents an actor (agent, person, role, system) with `actor_type` and `actor_id`
- **EntityRef**: Represents a business entity with `entity_type`, `entity_id`, and optional `system`
- **Value**: Typed value with `type` (string|int|bool|decimal|...) and string `value`
- **Fact**: Key-value pair with optional `as_of` timestamp
- **SourceObjectRef**: Reference to source system object
- **EvidenceRef**: Reference to evidence with locator and optional redacted excerpt
- **Violation**: Policy violation with code and details
- **Change**: Field change with path and value
- **ApprovalSubject**: Subject of approval (exception or action)

### Configuration Files Required

- **pyproject.toml**: Build config, dependencies, ruff/mypy settings → SSOT 5.3
- **importlinter.ini**: Module boundary contracts → SSOT 5.3

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: `pip install -e .` completes in under 30 seconds on standard hardware
- **SC-002**: `python -c "import decisiongraph"` executes in under 1 second
- **SC-003**: `mypy src/ --strict` exits with code 0
- **SC-004**: `ruff check src/` exits with code 0
- **SC-005**: `import-linter` exits with code 0
- **SC-006**: All 10 test cases from SSOT P0 pass (TC-P0-001 through TC-P0-010)
- **SC-007**: No runtime dependencies beyond Python stdlib for core module

### Test Cases (from SSOT 8.1)

| ID | Name | Description |
|----|------|-------------|
| TC-P0-001 | import_root | `import decisiongraph` succeeds |
| TC-P0-002 | error_codes_enum | Error codes match SSOT 7.2 |
| TC-P0-003 | dataclasses_construct | Domain types constructable |
| TC-P0-004 | mypy_strict_pass | mypy strict mode passes |
| TC-P0-005 | ruff_pass | ruff check passes |
| TC-P0-006 | import_linter_contract_domain_pure | Domain isolation enforced |
| TC-P0-007 | no_cycles | No circular imports |
| TC-P0-008 | packaging_src_layout | src-layout verified |
| TC-P0-009 | api_module_importable | `decisiongraph.api` importable |
| TC-P0-010 | version_exposed | `__version__` accessible |

---

## Dependencies & Constraints

### Depends On

- None (this is the first phase)

### Blocks

- 002-event-model (P1)
- All subsequent phases

### Frozen Decisions (from SSOT Section 4)

This phase implements the following frozen decisions:

- **DD-001**: Project name is "DecisionGraph"
- **DD-002**: License is Apache-2.0
- **DD-003**: Python 3.12+, src-layout
- **DD-004**: stdlib dataclasses (no pydantic)
- **DD-014**: import-linter + ruff + mypy for enforcement

---

## Files to Create

```
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
      canonical_json.py  # Stub with NotImplementedError
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
README.md               # Minimal usage
```

---

## SSOT References

- Section 5: Modular Repo Design
- Section 7.2: Error Codes
- Section 8.1: P0 Phase Definition
- Section 11.1: errors.py skeleton
- Section 11.2: domain/types.py skeleton
- Section 11.3: domain/events.py skeleton
