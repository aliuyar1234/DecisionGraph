# DecisionGraph

<section class="dg-hero">
  <div class="dg-hero__copy">
    <p class="dg-eyebrow">Local-first decision evidence for agents and automation</p>
    <h1>Deterministic audit trails, replay verification, and operator workflows.</h1>
    <p class="dg-hero__lede">
      DecisionGraph records immutable decision events, materializes deterministic projections,
      lets teams replay traces for proof, and ships a self-hosted BEAM runtime for
      operator-grade investigation and review.
    </p>
    <div class="dg-hero__actions">
      <a class="md-button md-button--primary" href="quickstart.md">Run the demo</a>
      <a class="md-button" href="showcase.md">See the product tour</a>
      <a class="md-button" href="release.md">Review the release evidence</a>
    </div>
  </div>
  <div class="dg-hero__panel">
    <div class="dg-stat">
      <span class="dg-stat__label">Current release</span>
      <strong>v0.1.0</strong>
    </div>
    <div class="dg-stat">
      <span class="dg-stat__label">Runtime posture</span>
      <strong>Self-hosted, single-node BEAM</strong>
    </div>
    <div class="dg-stat">
      <span class="dg-stat__label">Semantic authority</span>
      <strong>Python frozen reference core</strong>
    </div>
    <div class="dg-stat">
      <span class="dg-stat__label">Operational proof</span>
      <strong>Benchmarks, replay parity, release validation</strong>
    </div>
  </div>
</section>

## What DecisionGraph Actually Is

<div class="dg-card-grid">
  <a class="dg-card" href="reference/README.md">
    <h3>Semantic reference core</h3>
    <p>
      The Python package is the frozen oracle for event contracts, append semantics,
      replay invariants, fixtures, and parity decisions.
    </p>
  </a>
  <a class="dg-card" href="architecture/DECISIONGRAPH_PHOENIX_ARCHITECTURE.md">
    <h3>Self-hosted platform runtime</h3>
    <p>
      The BEAM umbrella owns the long-running product surface: Postgres event store,
      OTP projector runtime, authenticated APIs, LiveView console, workflows, and replay controls.
    </p>
  </a>
  <a class="dg-card" href="benchmarks/PHASE_10_RELEASE_VALIDATION.md">
    <h3>Evidence-driven release story</h3>
    <p>
      This repo includes benchmark baselines, resilience drills, parity reports,
      release validation tasks, and self-hosted operating guidance.
    </p>
  </a>
</div>

## Architecture At A Glance

<div class="dg-architecture">
  <div class="dg-surface">
    <p class="dg-surface__eyebrow">Python reference core</p>
    <h3>Frozen semantic authority</h3>
    <ul>
      <li>Embedded library and local CLI</li>
      <li>Golden fixture bundles and semantic baseline</li>
      <li>Canonical contracts for writes, projections, queries, and replay</li>
    </ul>
  </div>
  <div class="dg-bridge">
    <span>contracts</span>
    <span>parity</span>
    <span>release gates</span>
  </div>
  <div class="dg-surface">
    <p class="dg-surface__eyebrow">BEAM self-hosted platform</p>
    <h3>Runtime and operator product</h3>
    <ul>
      <li>Postgres append-only event store</li>
      <li>OTP projection workers, digests, and replay coordinators</li>
      <li>Phoenix API, LiveView operator console, and review workflows</li>
    </ul>
  </div>
</div>

The Phase 9 decision is deliberate:

- Python stays the semantic authority for the frozen core
- BEAM stays the runtime and delivery layer for the self-hosted product
- parity is used to prove alignment, not to hide the boundary

Start with these docs if you want the canonical story:

- [ADR: Phase 9 Semantic Authority](architecture/ADR_PHASE_9_SEMANTIC_AUTHORITY.md)
- [Semantic Authority Decision](architecture/SEMANTIC_AUTHORITY_DECISION.md)
- [Semantic Parity Policy](reference/SEMANTIC_PARITY_POLICY.md)
- [Phoenix Platform Architecture](architecture/DECISIONGRAPH_PHOENIX_ARCHITECTURE.md)

## What You Can Do With It

<div class="dg-card-grid">
  <a class="dg-card" href="api.md">
    <h3>Ingest and query decision traces</h3>
    <p>
      Append events, inspect traces, query context graphs, search precedents,
      and verify projection health through the service layer.
    </p>
  </a>
  <a class="dg-card" href="operations/OPERATOR_CONSOLE.md">
    <h3>Investigate live operational state</h3>
    <p>
      Use the operator console to review timelines, compare precedents,
      inspect policy outcomes, and manage replay workflows.
    </p>
  </a>
  <a class="dg-card" href="operations/WORKFLOW_RUNTIME.md">
    <h3>Run human review workflows</h3>
    <p>
      Escalate exceptions, route approvals, export workflow state, and keep an auditable
      trail of operator intervention on top of deterministic trace data.
    </p>
  </a>
  <a class="dg-card" href="operations/SELF_HOSTED_INSTALL.md">
    <h3>Self-host it without SaaS assumptions</h3>
    <p>
      DecisionGraph is built for local-first and private deployments with PostgreSQL,
      packaged BEAM releases, backup guidance, recovery drills, and upgrade runbooks.
    </p>
  </a>
</div>

## Choose Your Starting Path

| If you want to... | Start here |
| --- | --- |
| See the product quickly | [Showcase](showcase.md) and [Quickstart](quickstart.md) |
| Run the full self-hosted demo | [Self-Hosted Install](operations/SELF_HOSTED_INSTALL.md) and [Release Validation](benchmarks/PHASE_10_RELEASE_VALIDATION.md) |
| Understand the runtime architecture | [Phoenix Platform Architecture](architecture/DECISIONGRAPH_PHOENIX_ARCHITECTURE.md), [BEAM Supervision Tree](architecture/BEAM_SUPERVISION_TREE.md), [BEAM Store Contract](architecture/BEAM_STORE_CONTRACT.md) |
| Understand semantic guarantees | [V1 Contracts](v1-contracts.md), [Reference Overview](reference/README.md), [Semantic Parity Policy](reference/SEMANTIC_PARITY_POLICY.md) |
| Inspect operator workflows | [Workflow Runtime](operations/WORKFLOW_RUNTIME.md), [Workflow State Machine](reference/WORKFLOW_STATE_MACHINE.md), [Approval and Override Policy](operations/APPROVAL_AND_OVERRIDE_POLICY.md) |
| Review release readiness | [Release](release.md), [Self-Hosted Release Checklist](operations/SELF_HOSTED_RELEASE_CHECKLIST.md), [Post Release Review](operations/POST_RELEASE_REVIEW.md) |

## Product Tour

<div class="dg-path-grid">
  <a class="dg-path" href="showcase.md">
    <span class="dg-path__step">01</span>
    <div>
      <h3>Showcase</h3>
      <p>See the intended operator journey and how the product is positioned.</p>
    </div>
  </a>
  <a class="dg-path" href="quickstart.md">
    <span class="dg-path__step">02</span>
    <div>
      <h3>Quickstart</h3>
      <p>Clone the repo, sync dependencies, and get to the first useful local flow fast.</p>
    </div>
  </a>
  <a class="dg-path" href="operations/SELF_HOSTED_INSTALL.md">
    <span class="dg-path__step">03</span>
    <div>
      <h3>Self-Hosted Install</h3>
      <p>Bring up the supported topology, bootstrap accounts, and run the operator demo.</p>
    </div>
  </a>
  <a class="dg-path" href="api.md">
    <span class="dg-path__step">04</span>
    <div>
      <h3>API Surface</h3>
      <p>Review the network contract for event ingestion, trace reads, precedent search, and replay controls.</p>
    </div>
  </a>
</div>

## Proof And Readiness

<div class="dg-card-grid">
  <a class="dg-card" href="benchmarks/PHASE_8_RESILIENCE_BASELINE.md">
    <h3>Resilience baseline</h3>
    <p>Restart, recovery, backup, and self-hosted capacity guidance for the supported topology.</p>
  </a>
  <a class="dg-card" href="benchmarks/PHASE_9_PARITY_REPORT.md">
    <h3>Parity report</h3>
    <p>Evidence that the BEAM runtime stays aligned with the frozen Python reference scope.</p>
  </a>
  <a class="dg-card" href="benchmarks/PHASE_10_RELEASE_VALIDATION.md">
    <h3>Release validation</h3>
    <p>Release-candidate proof covering demo seeding, packaged runtime validation, and self-hosted checks.</p>
  </a>
</div>

## Documentation Map

### Run It

- [Quickstart](quickstart.md)
- [Self-Hosted Install](operations/SELF_HOSTED_INSTALL.md)
- [Backup and Restore](operations/BACKUP_AND_RESTORE.md)
- [Upgrade and Rollback](operations/UPGRADE_AND_ROLLBACK.md)
- [Disaster Recovery](operations/DISASTER_RECOVERY.md)
- [Self-Hosted Release Checklist](operations/SELF_HOSTED_RELEASE_CHECKLIST.md)

### Build On It

- [API Overview](api.md)
- [BEAM Service API](api/BEAM_SERVICE_API.md)
- [V1 Contracts](v1-contracts.md)
- [Reference Overview](reference/README.md)
- [Python SDK Service Compatibility](reference/PYTHON_SDK_SERVICE_COMPATIBILITY.md)

### Operate It

- [Operator Console](operations/OPERATOR_CONSOLE.md)
- [Projection Runtime](operations/PROJECTION_RUNTIME.md)
- [API Runtime](operations/API_RUNTIME.md)
- [Workflow Runtime](operations/WORKFLOW_RUNTIME.md)
- [Trace Investigation](operations/TRACE_INVESTIGATION.md)
- [Observability Dashboards](operations/OBSERVABILITY_DASHBOARDS.md)

### Understand It

- [Phoenix Platform Architecture](architecture/DECISIONGRAPH_PHOENIX_ARCHITECTURE.md)
- [Repo Evolution Map](architecture/REPO_EVOLUTION_MAP.md)
- [BEAM Supervision Tree](architecture/BEAM_SUPERVISION_TREE.md)
- [BEAM Projection Runtime](architecture/BEAM_PROJECTION_RUNTIME.md)
- [BEAM Store Contract](architecture/BEAM_STORE_CONTRACT.md)
- [Plans Overview](plans/index.md)

### Evaluate The Product Direction

- [Product North Star](vision/PRODUCT_NORTH_STAR.md)
- [Personas](product/PERSONAS.md)
- [V1 Platform Scope](product/V1_PLATFORM_SCOPE.md)
- [Workflow Demo Scenario](product/WORKFLOW_DEMO_SCENARIO.md)
- [Post Release Backlog](product/POST_RELEASE_BACKLOG.md)
