# BEAM Supervision Tree

## Purpose

This document defines the intended Phase 2 supervision layout for the Elixir umbrella.

It is not the long-term final tree for every future workflow. It is the bootstrap tree that gives DecisionGraph a safe, production-oriented runtime foundation before the write model and projector semantics are ported in later phases.

## Design Principles

- keep pure domain logic out of long-lived process state
- keep infrastructure ownership obvious at the app boundary
- use supervisors for runtime behavior, not for code organization
- isolate dynamic worker pools in `dg_projector`
- keep web delivery owned by `dg_web`
- keep database ownership in `dg_store`

## Phase 2 Tree

```text
DecisionGraph umbrella
|
|-- dg_domain
|   `-- DecisionGraph.Domain.Application
|       `-- no long-lived children in Phase 2
|
|-- dg_observability
|   `-- DecisionGraph.Observability.Application
|       `-- :telemetry_poller child
|
|-- dg_store
|   `-- DecisionGraph.Store.Application
|       `-- DecisionGraph.Store.Repo (when repo startup is enabled)
|
|-- dg_projector
|   `-- DecisionGraph.Projector.Application
|       |-- {Registry, keys: :unique}
|       |-- {DynamicSupervisor, strategy: :one_for_one}
|       `-- {Task.Supervisor, name: DecisionGraph.Projector.ReplaySupervisor}
|
|-- dg_api
|   `-- DecisionGraph.Api.Application
|       `-- {Task.Supervisor, name: DecisionGraph.Api.TaskSupervisor}
|
`-- dg_web
    `-- DecisionGraphWeb.Application
        |-- {Phoenix.PubSub, name: DecisionGraphWeb.PubSub}
        `-- DecisionGraphWeb.Endpoint
```

## What Each App Owns

### `dg_domain`

Owns:

- pure structs
- validation modules
- runtime naming helpers
- environment-independent contracts

Does not own:

- Repo connections
- PubSub
- background workers
- HTTP request processes

### `dg_observability`

Owns:

- telemetry attachment setup
- logger metadata conventions
- polling for VM/runtime metrics
- OpenTelemetry bootstrap
- boot event emission for observability startup

### `dg_store`

Owns:

- the Ecto repo
- connection pooling
- SQL migrations
- datastore configuration

### `dg_projector`

Owns:

- projector worker registry
- dynamic worker supervisor
- replay task supervisor
- later tenant/projection worker pools

This is the main runtime-heavy app in early phases.

### `dg_api`

Owns:

- service-layer orchestration processes
- internal control-plane boundaries
- future public/internal API runtime coordination

Phase 2 should keep this app thin. It exists to reserve the boundary cleanly.

### `dg_web`

Owns:

- Phoenix endpoint
- PubSub
- request-serving supervision
- LiveView and operator-facing web delivery

## Restart Strategy Guidance

- singleton infrastructure should use normal permanent supervision
- request processes remain transient and Phoenix-managed
- projector workers should restart independently without taking down the whole app
- replay tasks should be isolated from the web endpoint under `DecisionGraph.Projector.ReplaySupervisor`
- observability failures must never own the fate of the core runtime

## What Is Deliberately Not In This Tree Yet

Phase 2 should not yet introduce:

- tenant-scoped top-level supervisors
- workflow-specific supervisors
- notification fanout trees
- approval timers
- dead-letter processors
- cross-node clustering supervisors

Those belong in later phases once the runtime has real workloads to own.
