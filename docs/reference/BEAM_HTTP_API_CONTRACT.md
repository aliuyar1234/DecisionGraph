# BEAM HTTP API Contract

## Purpose

This document freezes the first HTTP-level conventions for the Phase 5 service surface.

These conventions sit above the already frozen semantic contracts for append, replay, graph traversal, and precedent lookup.

## Request Conventions

### Versioned Base Path

- all product API routes live under `/api/v1`

### Auth

- clients send `Authorization: Bearer <token>`

### Tenant Selection

- clients send `x-tenant-id: <tenant>`

### JSON

- request and response bodies use JSON

### Replay Requests

- replay and rebuild requests require a `reason`
- replay mode is `catch_up` or `rebuild`
- `projection` may be a specific projection name or `all`

### Request IDs

- clients may send `x-request-id: <id>`
- the server echoes or generates a request id on every response

## Success Envelope

Successful responses use:

```json
{
  "data": { "...": "..." },
  "request_id": "..."
}
```

## Error Envelope

Error responses use:

```json
{
  "error": {
    "code": "invalid_argument",
    "message": "human-readable message",
    "details": {}
  },
  "request_id": "..."
}
```

## Stable Error Codes

The first stable HTTP-facing error codes are:

- `unauthorized`
- `forbidden`
- `rate_limited`
- `invalid_argument`
- `not_found`
- `conflict`
- `idempotency_conflict`
- `event_sequence_invalid`
- `schema_violation`
- `projection_out_of_date`
- `storage`
- `internal_error`

## Status Mapping

The current mapping is:

- `400`: `invalid_argument`
- `401`: `unauthorized`
- `403`: `forbidden`
- `404`: `not_found`
- `409`: `conflict`, `idempotency_conflict`, `event_sequence_invalid`, `projection_out_of_date`
- `422`: `schema_violation`
- `429`: `rate_limited`
- `503`: `storage`
- `500`: `internal_error`

Replay status and cancel are tenant-scoped. If a caller knows a foreign tenant's `job_id`, the API should respond as `404 not_found`.

## Ordering And Semantic Rules

The HTTP layer must not weaken the frozen internal guarantees:

- trace event timelines stay ordered by `trace_seq`
- graph edge pages stay ordered by `log_seq ASC, edge_id ASC`
- precedent results stay ordered by `last_log_seq DESC, trace_id ASC`
- stale projection-backed reads fail explicitly rather than returning silently stale data

## Pagination

The initial cursor-bearing route is:

- `GET /api/v1/graph/edges`

Its cursor state is expressed through:

- `cursor_edge_key`
- `cursor_log_seq`

Future paginated routes should follow the same explicit-cursor style rather than implicit page numbers.

## Freshness And Polling

Projection-backed reads are allowed to fail with:

- `409 projection_out_of_date`

when the read model is behind the event log. Clients that need near-real-time results should poll rather than assuming synchronous projection completion.

## Admin Replay Request Rules

The admin replay endpoint:

- `POST /api/v1/admin/replays`

uses these stable request fields:

- `mode`: `catch_up` or `rebuild`
- `projection`: a projection name or `all`
- `reason`: required operator reason string
- `since_log_seq`: optional lower bound
- `until_log_seq`: optional upper bound
- `metadata`: optional JSON object merged into the durable replay run metadata

Admin replay routes also require:

- `admin` role authentication at the HTTP layer
- `projection_replay` or `projection_rebuild` permission depending on the run mode

## Rate Limiting

Versioned routes are rate limited in fixed one-minute buckets keyed by:

- service account id
- tenant id
- route scope

The first scopes are:

- `read`
- `write`
- `admin`

Rate-limit failures use:

- HTTP `429`
- error code `rate_limited`

## Compatibility And Deprecation

The Phase 5 HTTP surface follows a conservative compatibility policy:

- additive fields and routes may ship in `v1` without breaking existing clients
- removing fields, changing meanings, or tightening required input is a breaking change and must move behind a new versioned route surface
- deprecated behavior should be announced in the release notes before removal, following `docs/release.md`
- compatibility decisions should preserve the frozen semantic guarantees even when transport details evolve
