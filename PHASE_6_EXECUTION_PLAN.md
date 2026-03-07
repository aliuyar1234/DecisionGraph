# Phase 6 Execution Plan

## Purpose

This file turns Phase 6 from [DECISIONGRAPH_BEAM_MASTERPLAN.md](DECISIONGRAPH_BEAM_MASTERPLAN.md) into an active execution checklist.

Phase 6 is about building the Phoenix LiveView operator console so DecisionGraph feels investigation-grade, real-time, and operationally serious instead of just programmatically useful.

## Phase Goal

By the end of Phase 6 we should have:

- a coherent Phoenix LiveView operator console
- a trace explorer with event timelines and payload inspection
- graph and precedent investigation surfaces
- projection health and replay operations dashboards
- live event and system-status surfaces for operators
- polished UI states that make the platform feel product-grade

## Status

Current phase:
- [ ] Phase 6 active

Phase complete:
- [ ] Phase 6 complete

## Dependencies

Phase 6 depends on these earlier checkpoints:

- [x] Phase 0 direction and scope are frozen
- [x] Phase 1 semantic reference is frozen
- [x] Phase 2 Elixir umbrella foundation is in place
- [x] Phase 3 BEAM event store is in place
- [ ] Phase 4 projection runtime is complete enough for operator use
- [ ] Phase 5 service API is complete enough to support UI flows
- [ ] Phase 6 execution is approved and started

## Workstreams

- console shell and information architecture
- trace investigation experience
- graph and precedent investigation experience
- health, replay, and operator operations experience
- polish, accessibility, and realtime behavior

## Workstream 1 - Console Shell and Information Architecture

Goal:
- create a strong product frame before building deep surfaces

Tasks:
- [ ] define the top-level navigation model for traces, graph, precedents, health, replay, and admin
- [ ] define operator personas and the primary journeys each screen must support
- [ ] establish the visual system for typography, layout, density, and status states
- [ ] build reusable LiveView layouts, shells, and common UI components
- [ ] define how tenant and environment context is shown throughout the console
- [ ] define information hierarchy so urgent health issues surface before deep investigative tools

Deliverables:
- [ ] console information architecture doc in `docs/product/OPERATOR_CONSOLE_INFORMATION_ARCHITECTURE.md`
- [ ] reusable shell and component layer in `beam/apps/dg_web/lib/decision_graph_web/`
- [ ] UI direction notes in `docs/product/OPERATOR_CONSOLE_VISUAL_DIRECTION.md`

Acceptance Criteria:
- [ ] operators can move between the main console surfaces without losing tenant or environment context
- [ ] layout and component primitives are reusable enough that later screens do not reimplement navigation, status, and page framing
- [ ] the information hierarchy makes urgent health and investigation tasks obvious within the first screen or two

## Workstream 2 - Trace Investigation Experience

Goal:
- make individual decision traces easy to inspect, understand, and explain

Tasks:
- [ ] build a trace explorer index with filters for tenant, time, event type, and status
- [ ] build a trace detail page with event timeline and payload inspection
- [ ] show projection-backed summary and digest status on trace detail surfaces
- [ ] show idempotency, retry, and sequencing context where relevant
- [ ] add comparison affordances for trace revisions or replay differences where useful
- [ ] add export or copy-ready formats for investigator handoff

Deliverables:
- [ ] LiveView trace index and detail screens
- [ ] trace investigator components under `beam/apps/dg_web/lib/decision_graph_web/live/`
- [ ] operator usage notes in `docs/operations/TRACE_INVESTIGATION.md`

Acceptance Criteria:
- [ ] operators can find a trace, inspect its event timeline, and understand the current summary without dropping to raw database access
- [ ] trace details surface sequence, retry, and digest context clearly enough for incident investigation
- [ ] investigator workflows support realistic handoff through export or copy-ready outputs

## Workstream 3 - Graph and Precedent Investigation Experience

Goal:
- turn stored decision context into something operators can reason about visually

Tasks:
- [ ] build a context graph visualizer for trace relationships and decision context
- [ ] build a precedent search and browsing experience
- [ ] build a precedent comparison surface showing similar cases and outcome differences
- [ ] define how graph depth, filtering, and expansion are controlled interactively
- [ ] define how operators move from a precedent to a trace and back
- [ ] add clear empty, partial, and stale-data states for projection-backed views

Deliverables:
- [ ] graph and precedent LiveView screens
- [ ] graph visualization components and server-side data adapters
- [ ] experience notes in `docs/product/GRAPH_AND_PRECEDENT_INVESTIGATION.md`

Acceptance Criteria:
- [ ] operators can move from a trace to its graph context and related precedents without losing investigative context
- [ ] graph and precedent views handle empty, partial, or stale projection state explicitly rather than silently degrading
- [ ] precedent comparison makes outcome differences understandable enough to support human review and escalation

## Workstream 4 - Health, Replay, and Operator Operations Experience

Goal:
- give operators one place to understand system health and take safe action

Tasks:
- [ ] build a projection health dashboard with lag, cursor, and failure indicators
- [ ] build replay and rebuild console flows with explicit safeguards
- [ ] show replay progress, digest comparison results, and failure recovery hints
- [ ] add live event and system activity views where operator value is clear
- [ ] define environment and tenant status pages for operational overview
- [ ] ensure dangerous operations require clear confirmation and audit visibility

Deliverables:
- [ ] health and replay LiveView surfaces
- [ ] operator-safe action flows in `beam/apps/dg_web/`
- [ ] runbook alignment in `docs/operations/OPERATOR_CONSOLE.md`

Acceptance Criteria:
- [ ] operators can see projection health, replay status, and failure hints from one operational surface
- [ ] dangerous actions such as replay or rebuild require explicit confirmation and leave an auditable trail
- [ ] environment and tenant status views surface the minimum information needed to recognize degraded platform state quickly

## Workstream 5 - Polish, Accessibility, and Realtime Behavior

Goal:
- make the UI feel impressive in day-to-day use, not just functionally complete

Tasks:
- [ ] wire Phoenix PubSub or streaming updates where live state matters
- [ ] add polished loading, empty, stale, degraded, and failure states
- [ ] ensure keyboard navigation and accessibility semantics are credible
- [ ] define performance budgets for key operator screens
- [ ] add UI test coverage for major operator journeys
- [ ] run usability passes against the demo scenario defined in Phase 0
- [ ] capture screenshots or demo flows for future launch materials

Deliverables:
- [ ] realtime UI wiring and component states
- [ ] test coverage for major LiveView journeys
- [ ] UX baseline notes in `docs/benchmarks/PHASE_6_OPERATOR_UI_BASELINE.md`

Acceptance Criteria:
- [ ] realtime updates are used where they materially improve operator understanding rather than adding noise
- [ ] major screens feel usable with keyboard navigation, loading states, and degraded-state messaging in place
- [ ] baseline UX notes capture screen performance and interaction quality clearly enough for future regression review

## Reference Inputs

Phase 6 should stay aligned with these existing strategy assets:

- `docs/product/PERSONAS.md`
- `docs/product/V1_PLATFORM_SCOPE.md`
- `docs/product/DEMO_SCENARIO.md`
- `DECISIONGRAPH_PHOENIX_ARCHITECTURE.md`

The operator console should present the existing platform capabilities clearly rather than inventing semantics that the backend does not support.

## Validation

Phase 6 should be validated with:

- LiveView journey tests for trace, graph, precedent, health, and replay flows
- operator walkthroughs using the Phase 0 demo scenario
- accessibility and degraded-state checks on the major console surfaces
- screenshots or recordings showing the intended product experience

## Required Evidence

Phase 6 should not be accepted without:

- working trace, graph, precedent, and health screens in `dg_web`
- test coverage for major operator journeys
- operator-facing docs in `docs/operations/TRACE_INVESTIGATION.md` and `docs/operations/OPERATOR_CONSOLE.md`
- UX baseline notes in `docs/benchmarks/PHASE_6_OPERATOR_UI_BASELINE.md`

## Exit Criteria

Phase 6 is complete only when:

- [ ] operators can inspect traces, graph context, precedents, and projection health from one coherent console
- [ ] replay and health operations can be performed safely from the UI
- [ ] live status updates are used where they add real operator value
- [ ] loading, stale, and failure states are polished enough for serious use
- [ ] the UI supports the demo scenario defined in Phase 0 convincingly
- [ ] the product looks and behaves like a platform, not a raw admin scaffold

## Recommended Execution Order

1. console shell and information architecture
2. trace investigation surfaces
3. graph and precedent investigation surfaces
4. health, replay, and operations surfaces
5. polish, accessibility, and realtime behavior

## Immediate Next Actions

- [ ] define the console navigation and screen inventory
- [ ] build the shared layout and component foundation in `dg_web`
- [ ] implement the first trace investigation LiveView
- [ ] implement the projection health dashboard shell
- [ ] connect the first realtime status update through PubSub

## Notes

Rules for this phase:

- do not hide backend uncertainty behind over-designed UI
- prefer clear investigative workflows over generic dashboard clutter
- keep visual direction intentional and product-grade, not default Phoenix scaffolding
- treat stale or degraded projection state as a first-class UI condition
