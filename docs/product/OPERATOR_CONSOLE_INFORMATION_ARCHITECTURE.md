# Operator Console Information Architecture

## Purpose

This document defines the Phase 6 operator-console structure now implemented in the Phoenix LiveView shell.

The goal is to keep the highest-signal operational questions visible first:

- is the platform healthy right now
- which trace needs attention
- what policy and approval context explains the current state
- what historical context or replay action should happen next

## Primary Personas

The console is optimized for these personas from [PERSONAS.md](PERSONAS.md):

- decision operations lead
- compliance and risk investigator
- reliability and platform operator

## Top-Level Surfaces

The console keeps tenant and environment context visible while grouping the operator journey into seven anchors:

1. `Health`
2. `Trace`
3. `Graph`
4. `Precedents`
5. `Replay`
6. `Stream`
7. `Status`

## Surface Responsibilities

### Health

- projection lag, digests, stale projections, and open failures
- current replay queue pressure
- quick access to recent traces

### Trace

- selected trace summary
- event timeline with payload inspection
- copy-ready investigator handoff block

### Policy Review

- policy lineage and decision summary
- exception posture
- approval posture
- action proposal and commit state

### Graph

- trace-centered context graph snapshot
- node and edge visibility for policy, exception, and related trace context

### Precedents

- related historical decisions
- outcome comparison against the current trace
- direct jump back into a precedent trace

### Replay

- guarded replay request form
- digest alignment view
- recent replay runs and failure hints

### Stream

- recent tenant events with payload drill-down

### Status

- tenant metrics and workflow mix
- environment and runtime posture

## Information Priority

The home screen intentionally orders information like this:

1. hero context and alert banners
2. health summary cards
3. projection health and recent traces
4. selected trace and policy review
5. graph and precedent investigation
6. replay operations
7. live stream and environment summaries

This keeps urgent runtime issues visible before deeper investigation tools, without hiding the investigation tools behind separate navigation.

## Primary Journeys

### Incident Triage

1. check health summary and alert banners
2. pick the affected trace from recent traces
3. inspect the timeline and policy review cards
4. inspect graph and precedent context
5. decide whether replay or escalation is needed

### Approval Investigation

1. open the selected trace
2. review policy, exception, and approval cards
3. compare similar precedents
4. copy the handoff block into incident or review notes

### Runtime Recovery

1. review projection health and open failures
2. inspect replay history and digest alignment
3. queue catch-up or rebuild with explicit typed confirmation
4. watch the live event stream and status panels during recovery
