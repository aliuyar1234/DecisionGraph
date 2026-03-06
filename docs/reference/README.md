# Semantic Reference

This directory is the durable Phase 1 reference package for DecisionGraph.

Its job is simple: make the current Python implementation explicit enough that a BEAM implementation can prove parity instead of approximating it.

## Status

The Python implementation under `src/decisiongraph` is the semantic oracle until an explicit architecture decision says otherwise.

The baseline checkpoint name for this reference package is:

- `semantic-reference-python-v1`

## What Is Frozen Here

- event envelope structure
- supported event-type vocabulary
- payload shape expectations
- append, idempotency, and trace-sequencing behavior
- projection and replay behavior
- query ordering and staleness rules
- digest construction rules
- backend parity expectations

## Machine-Readable Reference Assets

- checked-in bundle: `tests/golden/reference_fixture_bundle.json`
- bundle exporter: `scripts/export_reference_fixture_bundle.py`
- source fixtures: `tests/golden/*`

## Reference Docs

- [Event Envelope Contract](EVENT_ENVELOPE_CONTRACT.md)
- [Payload Shape Matrix](PAYLOAD_SHAPE_MATRIX.md)
- [Append Semantics](APPEND_SEMANTICS.md)
- [Projection and Replay Semantics](PROJECTION_AND_REPLAY_SEMANTICS.md)
- [Precedent and Graph Query Semantics](PRECEDENT_AND_GRAPH_QUERY_SEMANTICS.md)
- [Query and Ordering Invariants](QUERY_AND_ORDERING_INVARIANTS.md)
- [Digest Invariants](DIGEST_INVARIANTS.md)
- [Storage Backend Expectations](STORAGE_BACKEND_EXPECTATIONS.md)
- [Semantic Parity Policy](SEMANTIC_PARITY_POLICY.md)
- [Parity Harness Plan](PARITY_HARNESS_PLAN.md)
- [Semantic Baseline Release Notes](SEMANTIC_BASELINE_RELEASE_NOTES.md)
