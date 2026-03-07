# BEAM Service API Boundary

## Purpose

This document defines the first Phase 5 HTTP boundary for the Phoenix-backed DecisionGraph service.

The service boundary is intentionally thin:

- `dg_api` owns service logic, auth decisions, rate limiting rules, and transport-safe error mapping
- `dg_web` owns Phoenix routing, plugs, controllers, and JSON delivery
- `dg_store` and `dg_projector` remain the authoritative write and projection engines behind the API

## Versioning

The first public service routes live under:

- `/api/v1`

The existing:

- `/api/healthz`

remains an unversioned deployment-health route rather than part of the versioned product API.

## Route Inventory

### Ingestion

- `POST /api/v1/events`

### Investigation Reads

- `GET /api/v1/traces/:trace_id`
- `GET /api/v1/graph/context`
- `GET /api/v1/graph/edges`
- `GET /api/v1/precedents`
- `GET /api/v1/projections/health`

### Admin

- `POST /api/v1/admin/replays`
- `GET /api/v1/admin/replays/:job_id`
- `POST /api/v1/admin/replays/:job_id/cancel`

## Role Tiers

The first service roles are:

- `reader`
- `writer`
- `admin`

Access intent:

- readers can query traces, graph, precedents, and projection health
- writers can ingest events and also use reader routes
- admins can use replay and rebuild controls in addition to reader and writer behavior

Replay controls add a second layer beyond the route role:

- `projection_replay` for catch-up admission and management
- `projection_rebuild` for rebuild admission and management

Replay controls add one more boundary beyond the `admin` role:

- `projection_replay` permission is required for catch-up replay status, start, and cancel operations
- `projection_rebuild` permission is required for rebuild start, status, and cancel operations
- deployment config can disable rebuilds entirely even for otherwise valid admin accounts

## Tenant Boundary

Every versioned API request must carry:

- `x-tenant-id`

Service-account auth is evaluated against that tenant before any route logic runs.

Replay status and cancel must also confirm that the addressed `job_id` belongs to the requested tenant before returning data.

Replay job lookups are also tenant-scoped after authentication:

- replay status and cancel only resolve jobs that belong to the caller's current `x-tenant-id`
- cross-tenant replay `job_id` guesses return `not_found` rather than leaking existence

## Delivery Rules

Controllers should stay thin and boring:

- parse request input
- delegate to one `dg_api` service module
- render a stable JSON envelope

They should not embed projection semantics, event-store logic, or ad hoc auth rules.

Replay and rebuild requests also require a human-readable `reason` so sensitive operator actions are explicit and auditable.
