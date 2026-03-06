# BEAM Store Contract

## Purpose

This document captures the current Phase 3 contract for the Elixir event store in `beam/apps/dg_store`.

The Python semantic reference remains authoritative. The BEAM store is considered correct only insofar as it preserves the observable behavior frozen in:

- `docs/reference/EVENT_ENVELOPE_CONTRACT.md`
- `docs/reference/APPEND_SEMANTICS.md`
- `docs/reference/STORAGE_BACKEND_EXPECTATIONS.md`
- `docs/reference/QUERY_AND_ORDERING_INVARIANTS.md`
- `docs/reference/SEMANTIC_PARITY_POLICY.md`

## Scope

Phase 3 covers:

- append-only persistence into Postgres
- idempotency enforcement
- `trace_seq` monotonicity enforcement
- post-`TraceFinished` write locking
- deterministic read ordering
- batch iteration for replay and projector catch-up
- projection-cursor storage for Phase 4 handoff
- store telemetry and domain-level error mapping

Phase 3 does not yet cover:

- BEAM-native projection tables
- BEAM-native projection digests
- BEAM-native graph, summary, or precedent query surfaces

Those remain Phase 4 work.

## Tables

### `dg_event_log`

Authoritative append-only event table.

Columns:

- `log_seq`: global append order
- `tenant_id`: tenant partition key
- `event_id`: caller-supplied event id
- `trace_id`: trace membership key
- `trace_seq`: per-trace sequence number
- `event_type`: frozen event vocabulary
- `occurred_at`: normalized RFC3339 timestamp string from the caller
- `recorded_at`: normalized RFC3339 timestamp string assigned at storage time
- `producer_id`: producer scope for idempotency
- `source_system`, `source_subsystem`
- `actor_type`, `actor_id`
- `correlation_id`, `causation_event_id`
- `idempotency_key`
- `schema_version`
- `payload_json`: canonical JSON string
- `payload_hash`: SHA-256 over canonical payload JSON
- `tags_json`: canonical JSON string for tags

Indexes and constraints:

- unique `event_id`
- unique `(tenant_id, trace_id, trace_seq)`
- unique `(tenant_id, producer_id, idempotency_key)`
- index `(tenant_id, trace_id, log_seq)`
- index `(tenant_id, event_type, log_seq)`
- index `(tenant_id, trace_id, event_type)`
- check constraints for non-negative `trace_seq`, positive `schema_version`, and valid `event_type`
- insert trigger for first-event rules, monotonic sequencing, and `TraceFinished` locking

### `dg_projection_cursors`

Reserved Phase 4 handoff table used to track projection catch-up state.

Columns:

- `tenant_id`
- `projection_name`
- `last_log_seq`
- `updated_at`

This table exists now so projector work can build on a stable cursor surface without revisiting migration shape.

## Append Contract

`DecisionGraph.Store.append_event/2` performs the following logical pipeline:

1. normalize the incoming Elixir `EventEnvelope`
2. validate required envelope fields, payload shape, idempotency key, tags, actor, source, and PII rules
3. canonicalize the payload and compute `payload_hash`
4. canonicalize tags
5. assign normalized `occurred_at` and `recorded_at`
6. acquire a per-trace advisory transaction lock
7. check for idempotent reuse under `(tenant_id, producer_id, idempotency_key)`
8. if a prior event exists, validate reuse metadata parity while intentionally excluding `trace_seq`
9. otherwise enforce next expected `trace_seq` and post-finish locking
10. insert and return `StoredEvent`

Observable guarantees:

- append-only persistence
- idempotent retries return the original stored event
- metadata drift on idempotent reuse raises `:idempotency_conflict`
- sequence drift raises `:event_sequence_invalid`
- post-finish writes raise `:conflict`
- storage failures are surfaced as `DecisionGraph.Error`

## Read Contract

Current read APIs in `DecisionGraph.Store`:

- `get_trace_events/2`
- `list_events/1`
- `iter_event_batches/1`
- `get_last_log_seq/1`
- `is_trace_finished/2`
- `get_next_trace_seq/2`
- `get_projection_cursor/2`
- `put_projection_cursor/3`
- `list_projection_cursors/1`

Ordering guarantees:

- `get_trace_events/2` returns `trace_seq ASC`
- `list_events/1` returns `log_seq ASC`
- `iter_event_batches/1` yields globally ordered, non-overlapping `log_seq` batches

Filters currently supported:

- `tenant_id`
- `trace_id`
- `event_type`
- `since_log_seq`
- `until_log_seq`
- `since_occurred_at`
- `until_occurred_at`
- `limit`

Bounds are validated before query execution:

- `since_log_seq <= until_log_seq`
- `since_occurred_at <= until_occurred_at`
- positive `limit` and `batch_size`

## Telemetry and Errors

Phase 3 emits:

- `[:store, :append, :stop]`
- `[:store, :append, :exception]`
- `[:store, :idempotency, :reuse]`
- `[:store, :read_batch, :stop]`

Metadata fields currently attached where applicable:

- `tenant_id`
- `trace_id`
- `event_type`
- `producer_id`
- `request_id`
- `error_code`

Stable domain-level error categories:

- `:invalid_argument`
- `:schema_violation`
- `:pii_policy_violation`
- `:idempotency_conflict`
- `:event_sequence_invalid`
- `:conflict`
- `:storage`

## Local Dev vs Production Notes

Accepted environment differences in Phase 3:

- local dev and test use Docker-hosted Postgres on `localhost`
- test uses `Ecto.Adapters.SQL.Sandbox`
- local benchmark guidance prefers `MIX_ENV=test` for quieter logs and isolated storage
- production is expected to use managed Postgres, stronger connection tuning, and observability aggregation beyond the local defaults

These are operational differences only. They must not change semantic outcomes.

## Accepted Phase 3 Limitations

- The BEAM runtime persists only the event log and projection cursors; projection materialization remains Phase 4 work.
- Benchmark numbers are baseline local measurements, not release SLOs.
- The store currently persists normalized RFC3339 strings for `occurred_at` and `recorded_at` to stay byte-stable with the current parity approach. A future switch to native Postgres time types is allowed only if observable semantics remain unchanged.
