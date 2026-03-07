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
- [V1.0 Scope and Contracts](v1-contracts.md)
- [Release Checklist](release.md)
- [Operations Runbook](operations.md)
- [Self-Hosted Install](operations/SELF_HOSTED_INSTALL.md)
- [Backup and Restore](operations/BACKUP_AND_RESTORE.md)
- [Upgrade and Rollback](operations/UPGRADE_AND_ROLLBACK.md)
- [Disaster Recovery](operations/DISASTER_RECOVERY.md)
- [Self-Hosted Release Checklist](operations/SELF_HOSTED_RELEASE_CHECKLIST.md)

## Semantic Reference

- [Semantic Reference Overview](reference/README.md)
- [Event Envelope Contract](reference/EVENT_ENVELOPE_CONTRACT.md)
- [Payload Shape Matrix](reference/PAYLOAD_SHAPE_MATRIX.md)
- [Append Semantics](reference/APPEND_SEMANTICS.md)
- [Projection and Replay Semantics](reference/PROJECTION_AND_REPLAY_SEMANTICS.md)
- [Precedent and Graph Query Semantics](reference/PRECEDENT_AND_GRAPH_QUERY_SEMANTICS.md)
- [Query and Ordering Invariants](reference/QUERY_AND_ORDERING_INVARIANTS.md)
- [Digest Invariants](reference/DIGEST_INVARIANTS.md)
- [Storage Backend Expectations](reference/STORAGE_BACKEND_EXPECTATIONS.md)
- [Semantic Parity Policy](reference/SEMANTIC_PARITY_POLICY.md)
- [Parity Harness Plan](reference/PARITY_HARNESS_PLAN.md)
- [Semantic Baseline Release Notes](reference/SEMANTIC_BASELINE_RELEASE_NOTES.md)

## Platform Strategy

- [Product North Star](vision/PRODUCT_NORTH_STAR.md)
- [ADR: Elixir Direction](architecture/ADR_ELIXIR_DIRECTION.md)
- [ADR: Python Reference Core](architecture/ADR_PYTHON_REFERENCE_CORE.md)
- [ADR: Phoenix Platform Role](architecture/ADR_PHOENIX_PLATFORM_ROLE.md)
- [Repo Evolution Map](architecture/REPO_EVOLUTION_MAP.md)
- [BEAM Supervision Tree](architecture/BEAM_SUPERVISION_TREE.md)
- [BEAM Process Ownership](architecture/BEAM_PROCESS_OWNERSHIP.md)
- [BEAM Store Contract](architecture/BEAM_STORE_CONTRACT.md)
- [Self-Hosted Topology](architecture/SELF_HOSTED_TOPOLOGY.md)
- [Storage Lifecycle](architecture/STORAGE_LIFECYCLE.md)
- [Single-Node Recovery](architecture/SINGLE_NODE_RECOVERY.md)
- [Personas](product/PERSONAS.md)
- [V1 Platform Scope](product/V1_PLATFORM_SCOPE.md)
- [Demo Scenario](product/DEMO_SCENARIO.md)
- [Phase 3 Store Baseline](benchmarks/PHASE_3_STORE_BASELINE.md)
- [Phase 8 Capacity Model](benchmarks/PHASE_8_CAPACITY_MODEL.md)
- [Phase 8 Resilience Baseline](benchmarks/PHASE_8_RESILIENCE_BASELINE.md)
