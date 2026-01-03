# Research: DecisionGraph Foundation

**Date**: 2026-01-01
**Phase**: P0 — Repo Bootstrap + Contracts

## Overview

No external research required - all technical decisions are frozen in SSOT Section 4.

## Decisions from SSOT

### DD-001: Project Name
- **Decision**: DecisionGraph
- **Rationale**: Combines "Decision" (core concept) with "Graph" (context graph projection)
- **Alternatives Rejected**: ContextTrace (too trace-focused), DecisionTraceGraph (too long)

### DD-002: License
- **Decision**: Apache-2.0
- **Rationale**: Permissive, enterprise-friendly, includes patent grant
- **Alternatives Rejected**: MIT (no patent grant), MPL-2.0 (copyleft elements)

### DD-003: Language/Layout
- **Decision**: Python 3.12+, src-layout (`src/decisiongraph`)
- **Rationale**: Modern Python, clear module boundaries, standard packaging
- **Alternatives Rejected**: Flat layout (import ambiguity), multi-language (scope)

### DD-004: Domain Types
- **Decision**: stdlib `dataclasses` + explicit validation functions
- **Rationale**: Minimal dependencies, deterministic serialization
- **Alternatives Rejected**: pydantic (extra dep), attrs (extra dep)

### DD-014: Module Enforcement
- **Decision**: import-linter + ruff + mypy
- **Rationale**: Deterministic, CI-enforceable, clear boundaries
- **Alternatives Rejected**: Convention only (not enforceable)

## Technology Stack (Frozen)

| Component | Choice | SSOT Reference |
|-----------|--------|----------------|
| Language | Python 3.12+ | DD-003 |
| Types | stdlib dataclasses | DD-004 |
| Linting | ruff | DD-014 |
| Type Checking | mypy strict | DD-014 |
| Module Boundaries | import-linter | DD-014 |
| Testing | pytest | SSOT 5.3 |
| Packaging | pyproject.toml | DD-003 |

## Error Codes (from SSOT 7.2)

```
DG_ERR_NOT_FOUND
DG_ERR_CONFLICT
DG_ERR_IDEMPOTENCY_CONFLICT
DG_ERR_SCHEMA_VIOLATION
DG_ERR_EVENT_SEQUENCE_INVALID
DG_ERR_PROJECTION_OUT_OF_DATE
DG_ERR_INVALID_ARGUMENT
DG_ERR_STORAGE
DG_ERR_PII_POLICY_VIOLATION
```

## Module Boundary Rules (from SSOT 5.3)

1. `domain` MUST NOT import from storage/projections/query/api
2. `query` MUST NOT import concrete backends (sqlite/postgres)
3. Layer order: serialization → domain → storage.interface → projections → query → api

## Conclusion

All technical decisions are pre-determined by SSOT frozen decisions. No research gaps identified.
