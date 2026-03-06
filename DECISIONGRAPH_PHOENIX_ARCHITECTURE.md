# DecisionGraph Phoenix Architecture

## Purpose

This document describes how to use Elixir, OTP, and Phoenix to turn DecisionGraph from a strong Python library into a serious, realtime, operator-grade platform.

This is not a full rewrite plan by itself.

It is the architecture plan for:

- how Phoenix fits into the product
- how OTP processes should be used
- which parts belong in APIs vs workers vs UI
- what the first real Phoenix milestone should be

## Big Picture

Recommended stack:

- Elixir for platform logic and runtime behavior
- OTP for supervision, workers, concurrency, and fault tolerance
- Phoenix for APIs, UI, websockets, and realtime collaboration
- Phoenix LiveView for the operator console
- Postgres as the production source of truth
- Python retained as the reference semantics implementation until parity is proven

The right mental model is:

- Python defines the current semantic truth
- Elixir runs the platform
- Phoenix exposes the platform

## Why Phoenix Is Valuable Here

Phoenix is a strong fit because DecisionGraph is not just a CRUD app.

It naturally benefits from:

- realtime state changes
- long-running replay and projection workflows
- collaborative investigation screens
- operator health dashboards
- background jobs with live progress
- approvals and exception flows
- streaming updates to browsers and services

Phoenix is especially useful when paired with BEAM because:

- workers can publish events into PubSub
- LiveView dashboards can react to state changes immediately
- APIs and operator tools can sit directly on top of supervised runtime processes
- multi-node scale is more natural than in a traditional web-only architecture

## Product Surfaces Phoenix Should Power

Phoenix should own these product surfaces:

- public and internal JSON APIs
- operator web console
- realtime sockets and subscriptions
- admin and maintenance tools
- authentication and session management
- tenant-scoped routing and authorization

Phoenix should not become the place where all domain logic lives.

Pure deterministic logic should stay in plain Elixir modules.

## Architecture Layers

Recommended layers:

1. Domain layer
- event schemas
- validation
- canonicalization
- deterministic projection rules
- digest generation
- query logic that is pure and testable

2. Runtime layer
- projection workers
- replay coordinators
- ingestion pipelines
- notification emitters
- approval workflow processes
- tenant-scoped supervisors

3. Delivery layer
- Phoenix controllers
- Phoenix LiveView screens
- Phoenix Channels or direct LiveView subscriptions
- admin endpoints

4. Persistence layer
- Postgres event log
- Postgres projections
- cursor metadata
- workflow records
- auth and tenant metadata

## Recommended Umbrella Apps

Recommended Elixir umbrella layout:

- `apps/dg_domain`
- `apps/dg_store`
- `apps/dg_projector`
- `apps/dg_api`
- `apps/dg_web`
- `apps/dg_observability`

### `apps/dg_domain`

Responsibilities:

- domain structs
- event type definitions
- validation rules
- payload normalization
- canonical serialization helpers
- deterministic digest logic
- query parameter validation

Rules:

- no Phoenix dependency
- no process-heavy logic
- maximize pure functions and testability

### `apps/dg_store`

Responsibilities:

- Ecto schemas where useful
- raw SQL where deterministic/event-log behavior matters
- event append path
- idempotency handling
- cursor reads and writes
- migration management
- batch read helpers

Rules:

- storage concerns only
- no UI logic
- no websocket logic

### `apps/dg_projector`

Responsibilities:

- projection engines
- supervised projection workers
- replay coordinators
- catch-up jobs
- digest comparison jobs
- projection lag and health inspection

Rules:

- owns process lifecycle around projections
- publishes status changes into PubSub

### `apps/dg_api`

Responsibilities:

- JSON API endpoints
- API versioning
- auth middleware
- request validation
- service-to-service contracts

Rules:

- thin delivery layer
- call domain and runtime services rather than burying logic in controllers

### `apps/dg_web`

Responsibilities:

- Phoenix LiveView operator UI
- incident and trace investigation pages
- replay controls
- health dashboards
- approval queues

Rules:

- optimized for operator experience
- heavily realtime

### `apps/dg_observability`

Responsibilities:

- telemetry events
- metrics
- tracing
- logging conventions
- alerting adapters

Rules:

- centralize the platform’s runtime visibility model

## OTP Process Model

Use OTP for runtime behavior, not for hiding ordinary functions.

### Good OTP use here

- one or more projection workers per projection stream
- replay coordinator processes
- tenant-scoped supervisors
- ingestion buffering or dispatch processes
- approval SLA timers
- notification fanout
- live health monitors

### Bad OTP use here

- wrapping every query in a GenServer
- storing deterministic business logic in process state
- using GenServer as a substitute for normal module design

## Supervisors

Recommended supervision tree shape:

- top-level application supervisor
- tenant supervisor layer
- projector supervisor layer
- replay supervisor layer
- notification supervisor layer
- Phoenix endpoint and PubSub supervision

Potential structure:

- `DecisionGraph.Application`
- `DecisionGraph.TenantSupervisor`
- `DecisionGraph.ProjectorSupervisor`
- `DecisionGraph.ReplaySupervisor`
- `DecisionGraph.NotificationSupervisor`
- `DecisionGraphWeb.Endpoint`
- `Phoenix.PubSub`

## Phoenix Delivery Patterns

### Controllers / JSON APIs

Use controllers for:

- event ingestion
- trace reads
- graph query reads
- precedent search
- health reads
- admin commands

API examples:

- `POST /api/v1/traces/:trace_id/events`
- `GET /api/v1/traces/:trace_id`
- `GET /api/v1/traces/:trace_id/events`
- `GET /api/v1/graph/subgraph`
- `GET /api/v1/precedents`
- `GET /api/v1/projections/health`
- `POST /api/v1/projections/replay`
- `POST /api/v1/approvals/:id/decide`

### LiveView

Use LiveView for:

- trace explorer
- projection health dashboard
- replay dashboard with live status
- approval inbox
- precedent comparison workspace
- incident investigation workspace

Why LiveView fits:

- server-rendered realtime UI
- excellent fit for internal tools and operator consoles
- natural PubSub integration
- easier consistency with runtime state than a separate SPA

### Channels or Socket Topics

Use Channels when non-browser realtime clients need subscriptions.

Possible consumers:

- agents
- internal services
- desktop tools
- automation daemons

Possible socket topic patterns:

- `tenant:{tenant_id}:projection_health`
- `tenant:{tenant_id}:trace:{trace_id}`
- `tenant:{tenant_id}:approvals`
- `tenant:{tenant_id}:replays`

If the first consumers are mostly browser operators, start with LiveView plus PubSub and delay Channel complexity until needed.

### Presence

Use `Phoenix.Presence` for collaborative operator use cases:

- who is viewing a trace
- who is reviewing an approval
- who is running a replay
- who is handling an incident

This is not required for v1, but it can make the product feel much more premium later.

## PubSub Design

Phoenix PubSub should be a core platform primitive.

### Event topics

Recommended topic families:

- `dg:tenant:{tenant_id}:trace:{trace_id}`
- `dg:tenant:{tenant_id}:projection_health`
- `dg:tenant:{tenant_id}:replay:{replay_id}`
- `dg:tenant:{tenant_id}:approval:{approval_id}`
- `dg:tenant:{tenant_id}:incident:{incident_id}`

### Event payload types

Recommended emitted events:

- `trace.event_appended`
- `trace.finished`
- `projection.cursor_advanced`
- `projection.stale_detected`
- `projection.replay_started`
- `projection.replay_progress`
- `projection.replay_finished`
- `projection.digest_mismatch`
- `approval.requested`
- `approval.decided`
- `exception.requested`
- `incident.opened`

### Publishing sources

Likely publishers:

- event ingestion service
- projection workers
- replay coordinators
- approval workflow service
- incident workflow service

## Where the Current DecisionGraph Features Map

Current feature to future Phoenix surface mapping:

- event append API -> Phoenix controller plus ingestion service
- projection sync/replay -> OTP workers plus admin LiveView
- projection health -> JSON endpoint plus health dashboard
- trace event reads -> API and trace explorer screen
- precedent queries -> API and analyst investigation screen
- context graph -> graph exploration page
- CLI admin actions -> internal admin endpoints and operator tools

## First Phoenix Milestone

This is the right first milestone:

### Milestone A - Operational Control Plane

Goal:
- prove Phoenix and OTP add real product value without needing a total rewrite

Deliverables:

- Phoenix app bootstrapped in the repo
- Postgres-backed health endpoint
- LiveView projection dashboard
- replay job with live progress
- trace lookup screen
- PubSub updates for health and replay state

Exact milestone tasks:

- [ ] create Phoenix umbrella app structure
- [ ] configure Postgres and Ecto
- [ ] add a minimal auth strategy for internal/operator use
- [ ] implement `GET /api/v1/projections/health`
- [ ] implement `POST /api/v1/projections/replay`
- [ ] implement replay job supervision
- [ ] implement PubSub events for replay lifecycle
- [ ] build LiveView health dashboard
- [ ] build LiveView replay controls and progress view
- [ ] build LiveView trace lookup page
- [ ] connect the dashboard to live PubSub updates
- [ ] add telemetry and logging for replay execution
- [ ] add smoke tests for the new operator surface

Why this milestone first:

- it shows off the BEAM advantage immediately
- it avoids rewriting everything at once
- it creates a visible, impressive product surface quickly
- it exercises workers, supervision, PubSub, LiveView, and APIs in one coherent slice

## Second Phoenix Milestone

### Milestone B - Trace and Precedent Intelligence UI

Deliverables:

- trace timeline explorer
- event payload inspector
- precedent search screen
- precedent comparison view
- context graph page

Tasks:

- [ ] implement trace details endpoint
- [ ] implement precedent query endpoint
- [ ] implement graph query endpoint
- [ ] build timeline explorer LiveView
- [ ] build payload diff/payload inspector UI
- [ ] build precedent search UI
- [ ] build precedent comparison UI
- [ ] build graph visualization page
- [ ] add deep-link routing into traces, approvals, and incidents

## Third Phoenix Milestone

### Milestone C - Human Workflow Layer

Deliverables:

- approval inbox
- exception handling workspace
- escalation timers
- collaborative incident views

Tasks:

- [ ] add approval workflow persistence
- [ ] add approval endpoints
- [ ] add approval LiveView inbox
- [ ] add exception request UI
- [ ] add Presence for collaborative review
- [ ] add notification hooks
- [ ] add audit export support

## API Design Guidance

Rules:

- keep public APIs versioned from day one
- keep event ingestion explicit and append-only
- keep replay/admin endpoints isolated and protected
- expose projection lag and status as first-class concepts
- expose deterministic IDs and timestamps in operator-facing endpoints
- separate public agent APIs from operator/admin APIs where helpful

## UI Design Guidance

The operator UI should feel premium, not like an internal CRUD dashboard.

Principles:

- realtime by default where it adds confidence
- strong visual hierarchy around traces, health, and approvals
- timelines and graph views should be first-class
- dashboards should emphasize freshness, lag, failures, and actionability
- use motion and live updates carefully to make the system feel alive
- prioritize fast investigation flow over generic admin-table design

## Security and Multi-Tenancy

Phoenix responsibilities here:

- route scoping by tenant or workspace
- operator auth and session controls
- API token auth for services
- audit logging for privileged actions
- authorization around replay, health, and admin operations

Tasks:

- [ ] define tenant boundary model
- [ ] define auth model for APIs and operators
- [ ] define authorization model for admin operations
- [ ] define audit policy for replay and override actions

## Risks

Main risks:

- pushing too much domain logic into GenServers
- overbuilding realtime complexity before core parity is stable
- mixing public API concerns with internal operator concerns
- trying to replace Python semantics too early
- under-designing tenant and auth boundaries

## Recommended Build Order

Recommended order:

1. Phoenix bootstrap and internal auth
2. projection health JSON endpoint
3. replay worker plus admin endpoint
4. LiveView health and replay dashboard
5. trace read endpoints and trace lookup UI
6. precedent and graph endpoints
7. investigation and comparison screens
8. approvals and exception workflows
9. collaborative Presence features

## Success Criteria

This Phoenix architecture is working when:

- [ ] operators can see live health, lag, and replay status in one place
- [ ] background workers and failures are visible and controlled
- [ ] traces and precedents are explorable from a polished UI
- [ ] realtime updates make the system feel alive and trustworthy
- [ ] APIs are useful to agents and service integrations
- [ ] the platform feels like a serious decision operations product rather than just a storage library
