# Phase 10 Release Validation

## Purpose

This document records the first serious self-hosted release-candidate validation run for the BEAM platform.

It exists to prove that the Phase 10 release path is not just documented. It was exercised end to end against a real local topology with seeded operator data, authenticated API checks, and replay verification.

## Release Candidate

- release candidate: `v0.1.0`
- captured at: `2026-03-07T16:31:59Z`
- validation report: `.tmp/phase10-release-validation.json`
- seeded demo report: `.tmp/phase10-demo-report.json`

## Topology Used

- deployment model: self-hosted, source-first
- runtime: Phoenix and OTP applications under `beam/`
- database: `decisiongraph_beam_dev`
- environment: `MIX_ENV=dev`
- HTTP endpoint: `http://127.0.0.1:4105`
- tenant used for seeded operator data: `release-demo`
- dependencies: repo `docker-compose.yml` Postgres service plus optional OTEL collector

## Commands Run

From the repository root:

```bash
docker compose up postgres otel-collector -d
cd beam
mix setup
mix dg.demo.seed --output ../.tmp/phase10-demo-report.json
mix dg.release.validate --output ../.tmp/phase10-release-validation.json
```

The release workflow in `.github/workflows/release.yml` now runs the same BEAM validation path before publishing a tagged release.

## Seeded Demo Profile

The release validation uses the `phase10_release_demo` dataset.

Seeded highlights:

- `22` events
- live exception trace:
  - `trace-live-renewal-002`
- precedent trace:
  - `trace-precedent-renewal-001`
- incident review trace:
  - `trace-incident-review-003`
- live exception workflow:
  - `trace-live-renewal-002:exception:ex-live-renewal-002`
- incident review workflow:
  - `trace-incident-review-003:trace_review:incident_triage`
- open workflows shown in the operator inbox:
  - `2`
- overdue workflows shown in the operator inbox:
  - `2`

The seeded workflows are intentionally overdue and escalated so the operator console shows SLA pressure, escalation state, precedent context, and incident review posture immediately after bootstrap.

## Checks Performed

The release validator passed all required checks:

- `GET /api/healthz`
- operator console HTML load for the seeded trace and workflow route
- authenticated projection health
- authenticated trace read for `trace-live-renewal-002`
- authenticated workflow list for the seeded inbox
- authenticated workflow export for the incident review item
- replay admission and completion round trip

## Evidence Captured

The validation artifacts capture:

- exact HTTP endpoint and topology metadata
- seeded trace IDs and workflow IDs
- selected console routes and API paths
- current projection results for the seeded tenant
- per-check pass or fail status
- full release validation success state

The seeded demo report also records the current projection digests for the candidate run. Those digests should be treated as release evidence for that run, not as globally stable documentation literals, because repeated validation against a long-lived development database can advance global log sequence values.

## Findings Fixed During Validation

Phase 10 validation surfaced two real release blockers before the release path was documented as ready:

- development reader and writer tokens were initially scoped only to the `default` tenant, which broke the isolated `release-demo` showcase path
- workflow runtime notification and action IDs relied on `System.unique_integer()`-based identifiers that could collide across BEAM process lifecycles

Both issues were fixed before this validation result was recorded:

- `beam/config/dev.exs` now authorizes the development reader and writer accounts for both `default` and `release-demo`
- `beam/apps/dg_api/lib/decision_graph/api/workflows.ex` now uses UUID-backed workflow notification and action identifiers

## Release Readiness Interpretation

This validation run is enough to support a serious self-hosted release candidate for the current source-first topology.

It does not change the known first-release limitations:

- there is still no repository-provided app container image
- there is still no packaged OTP release artifact
- the supported path remains a source checkout with PostgreSQL
- Python remains the semantic reference and local embedded surface

## Follow-Through

This document should be refreshed whenever:

- the supported release topology changes
- the release validation command changes
- a new tag is prepared with materially different runtime behavior
- new release blockers are discovered during self-hosted validation
