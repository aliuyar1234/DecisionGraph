# Showcase

This page shows the fastest self-hosted DecisionGraph experience for the current BEAM platform release candidate.

The goal is not to show a toy dataset. It is to land you inside a realistic operator console with live trace investigation, precedent context, escalated workflows, and replay controls already in motion.

## 1. Start The Self-Hosted Runtime

From the repository root:

```bash
docker compose up postgres otel-collector -d
cd beam
mix setup
set PHX_SERVER=true
iex -S mix
```

This starts the supported Phase 10 topology:

- one BEAM node
- one PostgreSQL instance
- optional OTEL collector
- Phoenix on `http://localhost:4100`

## 2. Seed The Release Demo

In a second terminal:

```bash
cd beam
mix dg.demo.seed --output ../.tmp/phase10-demo-report.json
```

This seeds the `release-demo` tenant with a curated operator dataset:

- approved precedent:
  - `trace-precedent-renewal-001`
- live exception review:
  - `trace-live-renewal-002`
- incident review:
  - `trace-incident-review-003`

The seeded workflows are intentionally overdue and escalated so the console immediately shows SLA pressure and escalation behavior instead of a quiet happy path.

## 3. Open The Main Console Routes

Start with the live exception review:

- `http://localhost:4100/?tenant=release-demo&trace_id=trace-live-renewal-002&workflow_id=trace-live-renewal-002:exception:ex-live-renewal-002`

Then open the incident review view:

- `http://localhost:4100/?tenant=release-demo&trace_id=trace-incident-review-003&workflow_id=trace-incident-review-003:trace_review:incident_triage`

What you should see immediately:

- projection health and current digests
- a selected trace timeline with payload inspection
- precedent context linked from the approved renewal trace
- an escalated exception workflow with audit history
- a trace review workflow launched from an incident-style investigation

## 4. Probe The API Surface

The seeded demo reports these API paths:

- selected trace:
  - `/api/v1/traces/trace-live-renewal-002`
- workflow inbox:
  - `/api/v1/workflows`
- projection health:
  - `/api/v1/projections/health`
- workflow export:
  - `/api/v1/admin/workflows/trace-incident-review-003:trace_review:incident_triage/export`

Development tokens for local evaluation:

- reader:
  - `dev-reader-token`
- writer:
  - `dev-writer-token`
- admin:
  - `dev-admin-token`

Example:

```bash
curl http://localhost:4100/api/v1/projections/health -H "Authorization: Bearer dev-reader-token" -H "x-tenant-id: release-demo"
```

## 5. Run The One-Command Release Validation

```bash
cd beam
mix dg.release.validate --output ../.tmp/phase10-release-validation.json
```

This validates the real HTTP runtime by checking:

- `GET /api/healthz`
- operator console HTML for the seeded route
- authenticated projection health
- authenticated trace read
- authenticated workflow list
- authenticated workflow export
- replay admission and completion

The first recorded successful run is documented in `docs/benchmarks/PHASE_10_RELEASE_VALIDATION.md`.

## 6. Python Reference Demo Still Exists

The Python package remains the semantic reference and local embedded surface.

If you want the smaller SQLite-first demo, use:

```bash
uv sync
uv run python demo/run_demo.py --db demo/showcase.db --output demo/showcase_output.md --force
uv run python -m decisiongraph replay demo/showcase.db
```

That path is still useful for semantic inspection. The BEAM release demo is the platform showcase.
