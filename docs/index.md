# DecisionGraph

DecisionGraph is a local-first decision audit platform for AI agents and automation systems.
It records immutable events, produces deterministic projections, lets you replay any decision trace for verification, and now ships a self-hosted BEAM runtime with APIs, workflows, and an operator console.

## Highlights

- Append-only event log and deterministic replay evidence
- Python semantic reference plus BEAM self-hosted runtime
- Operator workflows, replay controls, and investigation UI
- SQLite and PostgreSQL support across the reference and platform surfaces

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
- [Semantic Authority Transition](operations/SEMANTIC_AUTHORITY_TRANSITION.md)
- [First Release Limitations](operations/FIRST_RELEASE_LIMITATIONS.md)
- [Early Adopter Feedback](operations/EARLY_ADOPTER_FEEDBACK.md)
- [Post Release Review](operations/POST_RELEASE_REVIEW.md)
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
- [Semantic Ownership Changelog](reference/SEMANTIC_OWNERSHIP_CHANGELOG.md)
- [Semantic Baseline Release Notes](reference/SEMANTIC_BASELINE_RELEASE_NOTES.md)

## Platform Strategy

- [Product North Star](vision/PRODUCT_NORTH_STAR.md)
- [ADR: Elixir Direction](architecture/ADR_ELIXIR_DIRECTION.md)
- [ADR: Python Reference Core](architecture/ADR_PYTHON_REFERENCE_CORE.md)
- [ADR: Phase 9 Semantic Authority](architecture/ADR_PHASE_9_SEMANTIC_AUTHORITY.md)
- [ADR: Phoenix Platform Role](architecture/ADR_PHOENIX_PLATFORM_ROLE.md)
- [Semantic Authority Inventory](architecture/SEMANTIC_AUTHORITY_INVENTORY.md)
- [Semantic Authority Decision Criteria](architecture/SEMANTIC_AUTHORITY_DECISION.md)
- [Phase 9 Recommendation Memo](architecture/SEMANTIC_AUTHORITY_RECOMMENDATION.md)
- [Semantic Governance](architecture/SEMANTIC_GOVERNANCE.md)
- [Python SDK Bridge Plan](architecture/PYTHON_SDK_BRIDGE_PLAN.md)
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
- [Phase 9 Parity Report](benchmarks/PHASE_9_PARITY_REPORT.md)
- [Phase 10 Release Validation](benchmarks/PHASE_10_RELEASE_VALIDATION.md)
- [Parity Infrastructure Maintenance](operations/PARITY_INFRASTRUCTURE_MAINTENANCE.md)
- [Post Release Backlog](product/POST_RELEASE_BACKLOG.md)
