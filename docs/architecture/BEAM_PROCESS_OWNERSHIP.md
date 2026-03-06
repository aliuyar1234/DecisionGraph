# BEAM Process Ownership

## Purpose

This document answers a simple question for the Phase 2 umbrella:

Which app owns which processes, and where should new runtime state live?

That matters because DecisionGraph is intentionally splitting pure logic from runtime behavior.

## Ownership Rules

### Rule 1

If the work is pure, deterministic, and stateless, it belongs in a plain module, not in a process.

Examples:

- event contract translation
- validation helpers
- payload normalization
- projection naming and partition helpers

### Rule 2

If the work owns runtime lifecycle, retries, or external coordination, it belongs under a supervisor.

Examples:

- Repo pools
- Phoenix endpoint runtime
- projector worker pools
- replay tasks
- telemetry pollers

## Ownership By App

### `dg_domain`

Owns no meaningful long-lived runtime state in Phase 2.

This app should provide:

- pure contracts
- helpers shared across apps
- compile-safe boundaries

### `dg_store`

Owns:

- database connections
- migration runtime
- datastore-facing configuration

This app is the only place that should directly own the Repo process tree.

### `dg_projector`

Owns:

- dynamic projector workers
- replay jobs
- per-worker runtime metadata
- later lag/cursor runtime supervision

This is the right home for concurrency-sensitive processes.

### `dg_api`

Owns:

- future API orchestration processes
- rate-limit / request coordination helpers if they require long-lived state

It should not own:

- PubSub
- endpoint lifecycle
- projector pools
- Repo pools

### `dg_web`

Owns:

- web endpoint processes
- web-facing PubSub infrastructure
- request-scoped metadata propagation
- LiveView runtime

### `dg_observability`

Owns:

- telemetry startup hooks
- pollers
- logger metadata conventions
- OpenTelemetry bootstrap state

## Process Classes

### Singleton Infrastructure

Examples:

- Repo
- PubSub
- Endpoint
- telemetry attachment supervisor

Owner:

- the app supervisor for the relevant boundary

### Dynamic Runtime Workers

Examples:

- projector workers
- replay jobs

Owner:

- `dg_projector`

### Request-Scoped Processes

Examples:

- Phoenix controller requests
- LiveView socket processes

Owner:

- `dg_web`

These are not part of the long-lived platform state model.

## Config Ownership

Config should be owned like this:

- umbrella `config/config.exs`: shared compile-time defaults
- `dev.exs`, `test.exs`, `prod.exs`: environment-specific compile config
- `runtime.exs`: secrets, URLs, ports, and deploy-time settings
- app-specific keys stay under their owning app namespace

This keeps configuration aligned with process ownership.

## Decision Rule For Future Work

When adding a new capability, ask:

1. Is it pure logic or runtime behavior?
2. Which app owns the external dependency or lifecycle?
3. Would a crash in this process conceptually belong to that app?

If those answers point to different apps, the boundary is probably wrong or the feature is trying to do too much in one place.
