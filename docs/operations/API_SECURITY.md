# API Security

## Purpose

This document captures the Phase 5 security boundary for the Phoenix-backed DecisionGraph service.

The public API is multi-tenant, authenticated, and intentionally conservative around replay and rebuild controls.

## Trust Boundary

The first HTTP service boundary assumes:

- clients authenticate with static service-account bearer tokens
- every versioned API request includes `x-tenant-id`
- tenant authorization happens before controller logic
- Phoenix controllers stay thin and delegate service logic to `dg_api`

The unversioned:

- `GET /api/healthz`

is a deployment-health route and not a tenant-scoped product API.

## Route Risk Levels

Lowest risk:

- `GET /api/v1/traces/:trace_id`
- `GET /api/v1/graph/context`
- `GET /api/v1/graph/edges`
- `GET /api/v1/precedents`
- `GET /api/v1/projections/health`

Medium risk:

- `POST /api/v1/events`

Highest risk:

- `POST /api/v1/admin/replays`
- `GET /api/v1/admin/replays/:job_id`
- `POST /api/v1/admin/replays/:job_id/cancel`

## Auth Model

Every versioned route requires:

- `Authorization: Bearer <token>`
- `x-tenant-id: <tenant>`

Service accounts are configured under:

- `beam/config/dev.exs`
- `beam/config/test.exs`

Each account carries:

- `roles`
- `tenant_ids`
- `permissions`

Role checks gate route families:

- `reader` for read APIs
- `writer` for ingestion
- `admin` for replay controls

Permission checks harden sensitive admin actions further:

- `projection_replay` for catch-up replay, replay status, and replay cancel
- `projection_rebuild` for rebuild creation, rebuild status, and rebuild cancel

## Tenant Isolation

Tenant isolation is enforced twice:

1. the auth plug rejects accounts that are not allowed to use the requested tenant
2. replay status and cancel lookups are scoped to the requested tenant before any result is returned

That second rule matters because replay jobs are addressed by `job_id`. A caller that knows another tenant's job ID should still receive `not_found`.

## Replay Safeguards

Replay and rebuild routes now enforce these safeguards:

- admin role is required
- an explicit replay permission is required
- rebuild can be disabled per environment through `:dg_api, :admin_controls`
- a human-readable `reason` is required by default for replay and rebuild requests
- operator metadata is persisted into replay run metadata

The default global control lives in:

- `beam/config/config.exs`

Current default:

- `allow_rebuild: false`
- `require_reason: true`

Development and test override rebuild to `true` so local flows remain usable.

## Audit Capture

Sensitive admin actions emit audit records through:

- logger entries with `api_action`, `account_id`, `job_id`, `request_id`, and `tenant_id`
- telemetry events under `[:decision_graph, :api, :admin, :audit]`

Current audited actions:

- replay/rebuild start
- replay cancel

Audit metadata is also written into replay run metadata where available:

- `reason`
- `request_id`
- requesting account identity and roles

## Rate Limiting

The API uses simple fixed-window ETS rate limiting keyed by:

- API scope
- service-account ID
- tenant ID
- current minute window

Configured buckets:

- `read`
- `write`
- `admin`

This is intentionally basic Phase 5 protection. It is enough to prevent accidental bursts and low-effort abuse, but it is not a replacement for upstream gateway controls.

## Threat Notes

This Phase 5 boundary does not yet provide:

- token rotation workflows
- signed request bodies
- IP allowlists
- per-endpoint quota policies
- durable audit exports
- external identity provider integration

Those remain later hardening work. For now, shared environments should treat the BEAM service as an authenticated internal platform service rather than an internet-exposed public API.
