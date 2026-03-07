# Self-Hosted Topology

## Purpose

This document defines the first officially supported DecisionGraph deployment shape for local-first, self-hosted operators.

The goal is to make one topology clearly supported before we broaden the matrix.

## Supported Topology

The supported Phase 10 topology is:

- one DecisionGraph BEAM application node
- one PostgreSQL 16 instance reachable from that node
- optional OpenTelemetry collector
- operator-managed source checkout from this repository

Packaging paths now available for that topology:

- source-first runtime from the repo checkout
- OTP release built with `mix release decisiongraph_beam`
- container image built from the packaged release with `beam/Dockerfile`
- optional source-building container path with `beam/Dockerfile.build`

This is a single-operator, single-node topology.
It is intended for:

- local development on a laptop or workstation
- internal evaluation on a trusted machine
- small self-hosted deployments on a home server or VPS

## Mandatory Components

The supported topology assumes these parts exist:

- the DecisionGraph repository checkout
- the `beam/` umbrella application
- Elixir `~> 1.19` and a compatible OTP release
- PostgreSQL as the authoritative datastore
- persistent disk for PostgreSQL data

## Optional Components

These parts are optional in the first supported topology:

- `otel-collector` from the repo `docker-compose.yml`
- a reverse proxy or TLS terminator in front of Phoenix
- a process supervisor such as `systemd`, NSSM, or a container runtime
- external backup storage for database dumps and restore drills

## Default Runtime Shape

The default runtime shape is:

- Postgres is the system of record
- the BEAM node owns API, projector, workflow, and operator-console behavior
- projection and workflow state are durable, but the append-only event log remains authoritative
- all failure recovery is designed around one node restarting and catching up, not cluster failover

Relevant defaults today:

- Phoenix listens on `http://localhost:4100` in development
- Postgres is exposed on `localhost:5432` by the repo `docker-compose.yml`
- `otel-collector` exposes OTLP on `4317` and `4318` when enabled

## Recommended Paths

### Local Operator Path

The default local path is:

1. start `postgres` and optionally `otel-collector` with `docker compose`
2. run `mix setup` from `beam/`
3. start Phoenix and the OTP supervision tree from source
4. use the built-in development service-account tokens for local evaluation only
5. optionally seed the `release-demo` tenant with `mix dg.demo.seed` for the operator showcase

This is the path documented in:

- `README.md`
- `beam/README.md`
- `docs/operations/SELF_HOSTED_INSTALL.md`

### Small-Server Path

The default small-server path is still source-first, but it is no longer limited to `mix phx.server`.

The supported shape is:

- one Linux or Windows host
- one Postgres instance on the same host or trusted local network
- `MIX_ENV=prod`
- `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, `PORT`, and `POOL_SIZE` configured for runtime
- Phoenix started from the repo checkout under `beam/`, or the packaged `decisiongraph_beam` OTP release

## Auth Defaults And Bootstrap Expectations

DecisionGraph is not treated as an anonymous local app.
Even in the first self-hosted topology, the operator is expected to bootstrap service-account access explicitly.

Current behavior:

- development config ships with `dev-reader-token`, `dev-writer-token`, and `dev-admin-token`
- the reader and writer tokens cover both `default` and `release-demo` for local evaluation
- those tokens are for local evaluation only
- production config does not ship with permanent public tokens
- replay controls require `operator_console_account_id` or an equivalent operator actor

Current supported bootstrap expectation:

- local evaluation may use the dev tokens on a trusted machine
- any network-accessible install should define its own service-account bootstrap file before exposure
- the default tenant can remain `default` until the operator needs more logical separation

Recommended bootstrap inputs:

- `mix dg.accounts.bootstrap --output ../.tmp/service-accounts.json`
- `DECISION_GRAPH_SERVICE_ACCOUNTS_FILE=/path/to/service-accounts.json`
- `DECISION_GRAPH_OPERATOR_ACCOUNT_ID=admin-main`

The bootstrap JSON format supports `tokens` lists per account, so token rotation can be handled by overlapping old and new tokens during a controlled transition window.

## Operating Assumptions

The first supported topology assumes:

- one trusted operator team controls the whole install
- the deployment is single-node, not clustered
- Postgres backups are the primary disaster-recovery artifact
- projection rebuild is acceptable for derived-state recovery
- workflow audit history should be treated as durable operational data, not disposable cache

## Phase 10 Release Demo Shape

The current release-demo seed path is part of the supported evaluation topology:

- the demo dataset is seeded into tenant `release-demo`
- the live review route focuses on `trace-live-renewal-002`
- the incident review route focuses on `trace-incident-review-003`
- the seeded workflows are intentionally escalated to make SLA pressure and queue handling visible on first load

This is still the same single-node topology. The demo does not introduce a second deployment shape.

## Unsupported Or Deferred Topologies

These are intentionally outside the first supported self-hosted posture:

- BEAM clustering and distributed worker ownership
- active-active or multi-region deployment
- hosted SaaS control-plane operation
- container-only application packaging without a source checkout
- per-tenant sharding or hard multi-tenant isolation work
- automatic scaling and cross-node replay coordination

Those can return later if product direction changes, but they are not required for a credible self-hosted v1.
