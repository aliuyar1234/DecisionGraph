# Digest Invariants

DecisionGraph uses deterministic SHA-256 digests to prove replay correctness.

## Covered Digests

The reference implementation computes:

- context graph digest
- trace summary digest
- precedent index digest
- full projection digest

`dg_policy_eval_index` is intentionally not part of the current digest surface.

## Deterministic Rules

- serialize using canonical JSON with sorted keys and no extra whitespace
- sort rows by stable keys before hashing
- exclude `recorded_at`
- use event-derived timestamps such as `created_at`, `started_at`, and `finished_at`
- include normalized `attrs` / `metadata_json`

## Row Ordering Rules

- context-graph nodes: `ORDER BY node_id`
- context-graph edges: `ORDER BY edge_id`
- trace summaries: `ORDER BY trace_id`
- precedent rows: `ORDER BY source_event_id`

## Full Digest Construction

The full projection digest is:

1. compute component digests
2. concatenate them as `"{graph}:{summary}:{precedent}"`
3. hash the concatenated string with SHA-256

## What Must Never Drift

- component digest values for the same event history
- sort order used to build digest inputs
- inclusion or exclusion of fields
- canonical JSON rules

Changing any of the above is a semantic change, not an implementation detail.
