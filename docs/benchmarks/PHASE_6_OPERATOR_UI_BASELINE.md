# Phase 6 Operator UI Baseline

## Purpose

This document records the first operator-console UX baseline for future Phase 6 regression checks.

## Implemented Surfaces

The current baseline includes:

- health summary cards and projection health dashboard
- recent-trace rail
- trace explorer with payload inspection and investigator handoff
- policy and exception review
- context graph visualizer
- precedent browser and comparison cards
- replay console with typed confirmation and digest alignment
- live event stream
- tenant and environment status panels

## Baseline Verification

Verified locally with:

- `mix test apps/dg_web/test/decision_graph_web/live/dashboard_live_test.exs`
- `mix test apps/dg_web/test`

## Expected Operator Experience

- the hero panel shows tenant, environment, projection posture, and current trace context immediately
- stale or failing runtime state appears in alert banners before the user has to interpret tables
- the selected trace can be followed through timeline, policy review, graph context, and precedents without leaving the page
- replay requests require typed confirmation and surface recent run history alongside digest alignment
- the live event stream and status panels update on the same refresh cycle as the health layer

## Demo Flow Capture Notes

Use the Phase 0 revenue-exception scenario as the canonical operator walkthrough:

1. open the console and confirm projection posture
2. select the active renewal trace from recent traces
3. inspect policy, exception, and approval cards
4. compare graph context and historical precedents
5. queue replay verification with typed confirmation
6. watch the event stream and status panels while the system refreshes
