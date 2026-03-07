# DecisionGraph

<div class="dg-intro">
  <p class="dg-kicker">Local-first decision evidence for agents and automation</p>
  <p class="dg-lede">
    DecisionGraph records immutable decision events, builds deterministic projections,
    verifies replay behavior, and ships a self-hosted BEAM runtime for investigation,
    approvals, and operational review.
  </p>
</div>

## Architecture

DecisionGraph has a deliberate split:

| Layer | Responsibility |
| --- | --- |
| Python reference core | Frozen semantic authority for contracts, fixtures, validation, append semantics, and replay invariants |
| Contract boundary | Parity tests, golden fixtures, and release gates that prove alignment |
| BEAM self-hosted runtime | Event store, projector runtime, Phoenix API, LiveView console, workflows, and operational tooling |

The canonical docs for that decision are:

- [ADR: Phase 9 Semantic Authority](architecture/ADR_PHASE_9_SEMANTIC_AUTHORITY.md)
- [Semantic Authority Decision](architecture/SEMANTIC_AUTHORITY_DECISION.md)
- [Semantic Parity Policy](reference/SEMANTIC_PARITY_POLICY.md)
- [Phoenix Platform Architecture](architecture/DECISIONGRAPH_PHOENIX_ARCHITECTURE.md)

## At A Glance

<div class="dg-grid">
  <a class="dg-link-card" href="quickstart.md">
    <strong>Quickstart</strong>
    <span>Get from clone to a useful local flow.</span>
  </a>
  <a class="dg-link-card" href="showcase.md">
    <strong>Showcase</strong>
    <span>See the intended operator journey.</span>
  </a>
  <a class="dg-link-card" href="operations/SELF_HOSTED_INSTALL.md">
    <strong>Self-Hosted Install</strong>
    <span>Bring up the supported local-first topology.</span>
  </a>
  <a class="dg-link-card" href="release.md">
    <strong>Release</strong>
    <span>Review the current release and evidence trail.</span>
  </a>
</div>

## What You Can Do

- Append and query decision traces through the service layer.
- Inspect traces, graphs, precedents, and projection health.
- Run operator workflows for approvals, escalations, and incident review.
- Self-host the runtime without SaaS assumptions.

## Read By Goal

| If you want to... | Start here |
| --- | --- |
| understand the product quickly | [Showcase](showcase.md) and [Quickstart](quickstart.md) |
| run the supported deployment | [Self-Hosted Install](operations/SELF_HOSTED_INSTALL.md) |
| understand the runtime architecture | [Phoenix Platform Architecture](architecture/DECISIONGRAPH_PHOENIX_ARCHITECTURE.md) and [BEAM Supervision Tree](architecture/BEAM_SUPERVISION_TREE.md) |
| understand the semantic guarantees | [V1 Contracts](v1-contracts.md), [Reference Overview](reference/README.md), and [Semantic Parity Policy](reference/SEMANTIC_PARITY_POLICY.md) |
| operate workflows and review trails | [Workflow Runtime](operations/WORKFLOW_RUNTIME.md) and [Operator Console](operations/OPERATOR_CONSOLE.md) |
| evaluate release quality | [Release](release.md), [Phase 10 Release Validation](benchmarks/PHASE_10_RELEASE_VALIDATION.md), and [Self-Hosted Release Checklist](operations/SELF_HOSTED_RELEASE_CHECKLIST.md) |

## Documentation Map

### Run

- [Quickstart](quickstart.md)
- [Self-Hosted Install](operations/SELF_HOSTED_INSTALL.md)
- [Backup and Restore](operations/BACKUP_AND_RESTORE.md)
- [Upgrade and Rollback](operations/UPGRADE_AND_ROLLBACK.md)
- [Disaster Recovery](operations/DISASTER_RECOVERY.md)

### Build

- [API Overview](api.md)
- [BEAM Service API](api/BEAM_SERVICE_API.md)
- [V1 Contracts](v1-contracts.md)
- [Reference Overview](reference/README.md)
- [Python SDK Service Compatibility](reference/PYTHON_SDK_SERVICE_COMPATIBILITY.md)

### Operate

- [Operator Console](operations/OPERATOR_CONSOLE.md)
- [Projection Runtime](operations/PROJECTION_RUNTIME.md)
- [API Runtime](operations/API_RUNTIME.md)
- [Workflow Runtime](operations/WORKFLOW_RUNTIME.md)
- [Trace Investigation](operations/TRACE_INVESTIGATION.md)
- [Observability Dashboards](operations/OBSERVABILITY_DASHBOARDS.md)

### Understand

- [Phoenix Platform Architecture](architecture/DECISIONGRAPH_PHOENIX_ARCHITECTURE.md)
- [Repo Evolution Map](architecture/REPO_EVOLUTION_MAP.md)
- [BEAM Projection Runtime](architecture/BEAM_PROJECTION_RUNTIME.md)
- [BEAM Store Contract](architecture/BEAM_STORE_CONTRACT.md)
- [Plans Overview](plans/index.md)

### Evaluate

- [Phase 8 Resilience Baseline](benchmarks/PHASE_8_RESILIENCE_BASELINE.md)
- [Phase 9 Parity Report](benchmarks/PHASE_9_PARITY_REPORT.md)
- [Phase 10 Release Validation](benchmarks/PHASE_10_RELEASE_VALIDATION.md)
- [Post Release Backlog](product/POST_RELEASE_BACKLOG.md)
