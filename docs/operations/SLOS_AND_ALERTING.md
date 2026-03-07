# SLOs And Alerting

## Purpose

This document defines the first practical health targets for the supported self-hosted topology.

These are self-hosted operator targets, not cloud-SaaS promises.

## What Matters Most

For the supported topology, the most important questions are:

- is the node up
- is Postgres reachable
- are projections current
- can operators read traces and workflows
- can admins still request replay when needed

## Target Signals

### Availability

Target:

- `/api/healthz` should be reachable and return `200` during normal operation

Operator expectation:

- any sustained `5xx` or connection failure on `/api/healthz` is page-worthy even in a single-node install

### Projection Freshness

Target:

- normal steady-state operation should keep `pending_events = 0` or near-zero for active tenants
- stale projections should self-correct quickly after brief write bursts

Operator watch threshold:

- any projection that remains stale for more than a few poll cycles deserves investigation

### Warm API Latency

Using the current Phase 8 local-hosting capture as a baseline:

- `GET /api/v1/traces/:trace_id` should remain comfortably sub-100 ms p95 on the supported warm local profile
- `GET /api/v1/projections/health` should remain comfortably sub-150 ms p95 on the same profile
- `POST /api/v1/events` should remain comfortably sub-50 ms p95 on the same profile
- `POST /api/v1/admin/replays` acceptance should remain comfortably sub-50 ms p95 on the same profile

These are intentionally conservative compared to the current measured numbers.

### Replay Safety

Target:

- replay acceptance remains cheap
- rebuild and catch-up durations remain predictable enough to reason about maintenance windows

Operator watch threshold:

- replay or rebuild taking materially longer than the recorded benchmark profile on the same data scale should trigger investigation

## First Alerting Rules

The first self-hosted alert posture should be simple:

- alert if `/api/healthz` fails repeatedly
- alert if any projection health response shows open failures
- alert if projection lag stays non-zero for a sustained period
- alert if replay jobs remain `queued` or `running` unexpectedly long
- alert if workflow backlog or escalation counts suddenly spike

For a single-node deployment, these can start as operator-watch rules instead of automated paging if the installation is small.

## Recommended Manual Watch Surfaces

- `/api/healthz`
- `GET /api/v1/projections/health`
- the operator console projection health cards
- the operator console replay panel
- workflow inbox counts and escalation indicators
- local logs with `request_id`, `trace_id`, `tenant_id`, `projection`, `job_id`, and `workflow_id`

## What Is Still Out Of Scope

Phase 8 does not require:

- hosted multi-tenant SLO segmentation
- external pager integrations
- fleet-wide SRE dashboards

The target is one operator being able to tell whether the self-hosted node is healthy.
