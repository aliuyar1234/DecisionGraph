# DecisionGraph

DecisionGraph is a **library-first** audit trail for AI agent decisions.
It records immutable events, produces deterministic projections, and lets you
replay any decision trace for verification.

## Highlights

- Append-only event log (immutable audit trail)
- Deterministic projection digests for reproducibility
- SQLite and PostgreSQL backends
- Read-only CLI tools for replay and trace dumps

## Architecture

```
Event Log -> Projector -> Query Layer
     |           |             |
  SQLite      Context       Precedent
  Postgres     Graph         Search
```

## Next steps

- [Showcase](showcase.md)
- [Quickstart](quickstart.md)
- [API Reference](api.md)
