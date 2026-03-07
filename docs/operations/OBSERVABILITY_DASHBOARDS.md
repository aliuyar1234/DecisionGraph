# Observability Dashboards

## Purpose

This guide explains which DecisionGraph health surfaces a self-hosted operator should actually look at.

The supported topology does not need a sprawling monitoring stack.
It needs a small number of trustworthy views.

## Primary Health Views

### Deployment Health

Use:

- `/api/healthz`

This is the top-level deployment view.
It combines:

- store deployment snapshot
- projector runtime snapshot
- projection health for the default tenant
- deployment environment metadata

Use it first when answering:

- is the node up
- is the repo connected to Postgres
- is the projector obviously unhealthy

### Projection Health

Use:

- `GET /api/v1/projections/health`
- operator console projection health cards

This is the most important operational view after node liveness.
It answers:

- what is the event-log tail
- which projections are stale
- whether failures are open
- whether replay jobs are still active

### Operator Console

Use:

- `/`

The console is the best single human-facing surface for:

- projection health
- recent traces
- workflow backlog
- replay operations
- environment status

### Runtime Snapshots

Direct BEAM runtime helpers remain useful during deeper investigation:

- `DecisionGraph.Store.deployment_snapshot/0`
- `DecisionGraph.Projector.runtime_snapshot/0`
- `DecisionGraph.Projector.projection_health/1`

## Log Signals

Current log metadata already includes:

- `request_id`
- `trace_id`
- `tenant_id`
- `projection`
- `worker`
- `account_id`
- `api_action`
- `job_id`
- `workflow_id`

For self-hosted operations, these fields are enough to correlate:

- request failures
- replay actions
- projector errors
- workflow incidents

## Optional OTEL Collector

The supported topology keeps OTEL optional.
If you start the repo `otel-collector` service, you get a cleaner path for forwarding telemetry, but the install is still supported without it.

## Minimal Dashboard Layout

If you build a lightweight local dashboard or external monitor, start with:

1. node up or down via `/api/healthz`
2. projection stale count
3. projection open failure count
4. active replay job count
5. workflow open count and escalated count

That is enough to answer whether the node is safe to trust.

## Investigation Order

When something looks wrong:

1. check `/api/healthz`
2. check projection health
3. check recent logs with request and projection metadata
4. inspect replay status if lag or failures are present
5. inspect workflow backlog only after runtime health is understood
