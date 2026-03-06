# Storage Backend Expectations

This document freezes what every storage backend must preserve.

## Applicable Backends

- SQLite
- PostgreSQL
- in-memory test store
- future BEAM-native stores

## Required Observable Behavior

- append-only event persistence
- global `log_seq` ordering
- per-trace `trace_seq` monotonicity
- `TraceStarted` first-event rule
- `TraceFinished` write lock
- idempotent retry reuse with `trace_seq` excluded from metadata matching
- stable `get_trace_events()` ordering by `trace_seq`
- stable `list_events()` ordering by `log_seq`
- accurate `get_last_log_seq()`
- accurate `get_next_trace_seq()`

## Batch Iteration

`iter_event_batches()` is allowed to choose different internal query shapes, but it must preserve:

- `log_seq` ordering across the whole stream
- no dropped events
- no duplicated events
- consistent handling of filters and bounds

## Backend-Specific Freedom

Backends may differ in:

- SQL syntax
- transaction strategy
- index structure
- connection lifecycle
- operational tuning

Backends may not differ in the semantic outcomes listed above.

## Reference Rule

If SQLite, PostgreSQL, and a future BEAM store disagree, Python parity assets are the tiebreaker until the architecture explicitly changes that rule.
