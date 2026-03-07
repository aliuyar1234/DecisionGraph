# Operator Console

## Purpose

This runbook explains the Phase 6 operator console surfaces and the intended operational workflow.

## Main Panels

- `Projection Health Dashboard`: lag, digests, stale projections, and open failures
- `Recent Traces`: quick entry into current trace investigation
- `Trace Explorer`: event timeline, payload inspection, and handoff block
- `Policy and Exception Review`: policy, exception, approval, and action posture
- `Context Graph Visualizer`: trace-centered graph context
- `Precedent Browser and Comparison`: related traces and outcome deltas
- `Replay Console`: guarded replay requests, digest alignment, replay history, and failure hints
- `Live Event Stream`: recent events for the active tenant
- `Tenant Status` and `Environment Status`: top-level runtime posture

## Replay Safety

Replay actions are intentionally guarded:

- the console shows which operator actor is executing the action
- rebuilds stay disabled unless the operator actor has rebuild permission
- the operator must provide a reason
- the operator must type the exact confirmation phrase before the replay request is accepted

## Live Update Model

The console refreshes automatically every 5 seconds.

That refresh cadence is used for:

- projection health
- replay state
- recent traces
- live event stream

Manual refresh remains available for operators who want an immediate sync after replay or investigation actions.
