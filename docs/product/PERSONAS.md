# Personas

## Purpose

This document defines the primary user personas for the future DecisionGraph platform.

These personas should shape API design, operator tooling, approval workflows, and product prioritization.

## Persona 1 - Platform and Agent Engineer

### Who They Are

An engineer building AI agents, automated workflows, or decisioning services that need structured event capture and trustworthy operational behavior.

### Core Goals

- instrument automated decisions without excessive friction
- query and replay decisions later
- integrate with a stable API and SDK surface
- keep production behavior observable and debuggable

### Pain Points

- ad hoc logging is not enough for real decision auditing
- once decisions are live, debugging becomes slow and fragmented
- approval and exception handling often become custom side systems

### What They Need From DecisionGraph

- clean ingestion APIs
- stable event contracts
- deterministic replay guarantees
- health and projection visibility
- Python support during the transition

## Persona 2 - Decision Operations Lead

### Who They Are

A product, operations, or platform owner responsible for keeping automated decision systems safe and effective in production.

### Core Goals

- know whether decision systems are healthy right now
- investigate incidents quickly
- monitor queues, lag, and workflow bottlenecks
- coordinate human review where needed

### Pain Points

- there is no single place to see system health and trace detail together
- handoffs between engineering, operations, and reviewers are messy
- operational visibility is often weaker than business expectations

### What They Need From DecisionGraph

- live health dashboards
- trace explorer and replay tools
- exception and approval views
- action-oriented alerts and workflow state visibility

## Persona 3 - Compliance and Risk Investigator

### Who They Are

A reviewer responsible for auditability, policy compliance, incident reconstruction, or post hoc evidence gathering.

### Core Goals

- understand exactly what happened
- prove who approved or overrode a decision
- compare similar historical decisions
- export evidence for audits, incidents, or internal review

### Pain Points

- conventional logs are noisy and incomplete
- incident reconstruction takes too long
- policy rationale and precedent history are hard to retrieve

### What They Need From DecisionGraph

- immutable trace history
- replay and digest verification
- precedent and graph exploration
- clear evidence exports

## Persona 4 - Human Reviewer and Approver

### Who They Are

A finance, risk, legal, trust, or operations reviewer who approves exceptions or intervenes in high-stakes automated decisions.

### Core Goals

- review only the context that matters
- approve or reject quickly but responsibly
- understand the policy basis and relevant precedents
- keep a clear audit trail of human intervention

### Pain Points

- most approval tools do not show enough context
- reviewers are forced to piece together information from multiple systems
- the audit trail for overrides is often weak

### What They Need From DecisionGraph

- focused approval inbox and review screens
- supporting trace and precedent context
- explicit decision capture and reasoning fields
- escalation and SLA support over time

## Secondary Persona - Reliability and Platform Operator

### Who They Are

An engineer responsible for uptime, recovery, replay safety, and operational resilience.

### What They Need

- projection lag visibility
- replay controls
- failure telemetry
- runtime and tenant status views

## Priority Order

Primary priority order for v1:

1. platform and agent engineer
2. decision operations lead
3. compliance and risk investigator
4. human reviewer and approver

This ordering keeps the product grounded in real integration and runtime value while still building toward high-trust operational workflows.
