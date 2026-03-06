# V1 Platform Scope

## Purpose

This document defines the minimum credible v1 scope for the future DecisionGraph platform.

It is intentionally ambitious, but it is not the full end-state roadmap.

## Product Definition

V1 is a self-hostable decision operations platform for AI agents and high-stakes automation.

It must feel like more than a tracing library.

It must prove that DecisionGraph can act as:

- a developer integration surface
- an operator control plane
- a compliance and investigation system
- a human review workflow layer for important decision exceptions

## Deployment Posture

Chosen v1 posture:

- self-hosted enterprise support is required from the start
- managed cloud is a later phase, not a v1 requirement
- Postgres is the production primary datastore
- logical multi-tenancy is required in v1
- v1 can remain single-region and does not need active-active multi-region support

## In Scope for V1

### 1. Platform Runtime

- Postgres-backed event log
- supervised projection runtime
- projection lag and health tracking
- deterministic replay support
- digest generation and verification

### 2. API Surface

- authenticated event ingestion API
- trace read APIs
- projection health APIs
- precedent search APIs
- graph query APIs
- admin endpoints for replay and platform operations

### 3. Operator Console

- LiveView-based operator UI
- projection health dashboard
- replay console with progress and result visibility
- trace lookup and trace investigation screens
- precedent exploration screens

### 4. Human Workflow Support

- exception request handling
- approval queue and review screens
- decision capture for approvals and rejections
- audit trail for human interventions

### 5. Tenant and Access Boundaries

- organization or workspace isolation
- operator authentication
- service account or API token support
- authorization around admin and replay actions

### 6. Python Continuity

- current Python implementation remains the semantic reference
- Python-facing usage remains supported while the platform evolves

## Explicitly Out of Scope for V1

- fully managed SaaS offering
- billing, subscription, or commercial packaging systems
- no-code workflow builder
- marketplace of third-party connectors
- advanced machine-learning similarity ranking beyond deterministic precedent surfaces
- multi-region active-active deployments
- mobile-first operator experiences
- generalized BI and reporting suite

## After V1

Strong candidates for post-v1 work:

- managed cloud offering
- richer Presence and collaborative review experiences
- connector ecosystem for CRM, ticketing, and policy systems
- advanced semantic search and precedent ranking
- multi-region resilience
- richer simulation and dry-run workflows

## Minimum Credible V1 Test

V1 should be considered credible only if a team can:

- send decision events into the platform
- see projection health in real time
- inspect a trace from the UI
- search for precedents
- route a policy exception to a human reviewer
- replay the system and verify deterministic results

If any of those are missing, the product is still too close to "library plus extras" rather than a real platform.
