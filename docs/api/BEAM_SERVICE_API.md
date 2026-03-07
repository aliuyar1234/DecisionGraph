# BEAM Service API

## Purpose

This guide is the operator and consumer entrypoint for the Phase 5 HTTP service.

The BEAM service exposes the DecisionGraph store and projector runtime through authenticated Phoenix routes while preserving the semantic guarantees frozen in the Python reference.

## Base URLs

Deployment health:

- `/api/healthz`

Versioned product API:

- `/api/v1`

## Auth

Every versioned request must include:

```http
Authorization: Bearer <token>
x-tenant-id: <tenant>
```

Development tokens are configured in:

- `beam/config/dev.exs`

## Route Inventory

Write path:

- `POST /api/v1/events`

Read paths:

- `GET /api/v1/traces/:trace_id`
- `GET /api/v1/graph/context`
- `GET /api/v1/graph/edges`
- `GET /api/v1/precedents`
- `GET /api/v1/projections/health`

Admin paths:

- `POST /api/v1/admin/replays`
- `GET /api/v1/admin/replays/:job_id`
- `POST /api/v1/admin/replays/:job_id/cancel`

## Response Shape

Success responses:

```json
{
  "data": {},
  "request_id": "..."
}
```

Error responses:

```json
{
  "error": {
    "code": "invalid_argument",
    "message": "human-readable explanation",
    "details": {}
  },
  "request_id": "..."
}
```

## Example Flows

### 1. Append an Event

```bash
curl -X POST http://localhost:4100/api/v1/events \
  -H "Authorization: Bearer dev-writer-token" \
  -H "x-tenant-id: default" \
  -H "content-type: application/json" \
  -d '{
    "actor": {"actor_id": "demo-agent", "actor_type": "agent"},
    "event_id": "trace-demo-trace_started-0",
    "event_type": "TraceStarted",
    "idempotency_key": "start:trace-demo",
    "occurred_at": "2025-12-31T15:00:00Z",
    "payload": {
      "primary_entity": {"entity_id": "account-42", "entity_type": "account", "system": "crm"},
      "title": "Demo trace",
      "workflow": "beam_service_demo"
    },
    "source": {"producer_id": "demo", "subsystem": "api", "system": "example"},
    "trace_id": "trace-demo",
    "trace_seq": 0
  }'
```

### 2. Poll Trace Readability

Projection-backed reads may temporarily return `projection_out_of_date` while workers catch up. Clients that need near-real-time results should poll.

```bash
curl http://localhost:4100/api/v1/traces/trace-demo \
  -H "Authorization: Bearer dev-reader-token" \
  -H "x-tenant-id: default"
```

### 3. Start a Replay

Replay and rebuild requests require an explicit reason.

```bash
curl -X POST http://localhost:4100/api/v1/admin/replays \
  -H "Authorization: Bearer dev-admin-token" \
  -H "x-tenant-id: default" \
  -H "content-type: application/json" \
  -d '{
    "mode": "catch_up",
    "projection": "trace_summary",
    "reason": "close projector lag after maintenance"
  }'
```

### 4. Poll Replay Status

```bash
curl http://localhost:4100/api/v1/admin/replays/<job_id> \
  -H "Authorization: Bearer dev-admin-token" \
  -H "x-tenant-id: default"
```

## Polling Semantics

Phase 5 currently supports polling, not streaming.

Use polling for:

- trace readability after writes
- projection health monitoring
- replay and rebuild job status

Clients should treat:

- `409 projection_out_of_date`

as an explicit signal that a projection-backed read is not ready yet.

## Read Ordering Guarantees

The HTTP API preserves the frozen internal guarantees:

- trace event timelines are ordered by `trace_seq`
- graph edge pages are ordered by `log_seq ASC, edge_id ASC`
- precedent results are ordered by `last_log_seq DESC, trace_id ASC`

## OpenAPI

The checked-in OpenAPI artifact lives at:

- `docs/api/BEAM_SERVICE_OPENAPI.yaml`

Use it as the first source for route discovery, then use the reference docs for semantic constraints that are stronger than transport shape alone.
