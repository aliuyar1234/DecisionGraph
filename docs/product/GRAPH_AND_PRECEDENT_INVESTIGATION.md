# Graph and Precedent Investigation

## Purpose

This document explains the Phase 6 investigation surfaces for graph context and precedent comparison.

## Context Graph

The graph view is centered on the selected trace.

The current UI shows:

- the center trace id
- node count and edge count
- whether the snapshot was truncated
- a readable list of related nodes
- a readable list of relationship edges

This is intentionally simple and server-driven. The goal is to preserve investigation clarity before adding more complex browser-side graph interactions.

## Precedent Browser

The precedent view is anchored to the selected trace and shows:

- the current trace id
- the current entity and outcome
- related historical traces
- outcome deltas
- policy lineage
- quick links back into the precedent trace

## Investigation Loop

Operators should move through these screens like this:

1. pick a trace from the recent-trace rail
2. inspect the trace and policy cards
3. review the trace-centered graph to understand relationships
4. inspect precedent outcomes and policy lineage
5. jump directly into a precedent trace when comparison needs more detail

## Empty and Stale State Rules

- missing graph context must render an explicit empty or unavailable state
- missing precedents must say that no matching precedents were found
- stale projections must already be visible in the health layer so graph or precedent uncertainty is never silent
