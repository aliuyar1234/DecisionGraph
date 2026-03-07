# Phase 5 Execution Plan

## Purpose

This file turns Phase 5 from [DECISIONGRAPH_BEAM_MASTERPLAN.md](DECISIONGRAPH_BEAM_MASTERPLAN.md) into an active execution checklist.

Phase 5 is about turning the BEAM runtime into a real platform service through Phoenix APIs, authenticated administration, and stable external contracts.

## Phase Goal

By the end of Phase 5 we should have:

- a real Phoenix API surface backed by the BEAM store and projector runtime
- authenticated event ingestion endpoints
- stable trace, graph, precedent, and projection health endpoints
- guarded replay and admin control endpoints
- tenant-aware authorization and abuse protection
- OpenAPI documentation and end-to-end service validation

## Status

Current phase:
- [x] Phase 5 active

Phase complete:
- [x] Phase 5 complete

## Dependencies

Phase 5 depends on these earlier checkpoints:

- [x] Phase 0 direction and scope are frozen
- [x] Phase 1 semantic reference is frozen
- [x] Phase 2 Elixir umbrella foundation is in place
- [x] Phase 3 BEAM event store is in place
- [x] Phase 4 projection runtime is complete enough for service use
- [x] Phase 5 execution is approved and started

## Workstreams

- API contract and boundary design
- ingestion and read APIs
- admin, auth, and tenant controls
- documentation, SDK alignment, and compatibility
- end-to-end validation and operability

## Workstream 1 - API Contract and Boundary Design

Goal:
- define the external service surface before endpoint sprawl begins

Tasks:
- [x] define the public API domains: ingestion, traces, graph, precedents, health, and admin
- [x] decide which logic lives in `dg_api` versus Phoenix controllers and plugs
- [x] define request and response envelope conventions
- [x] define error response shape and stable error codes
- [x] define pagination, filtering, and sorting conventions across endpoints
- [x] define versioning strategy for the public HTTP surface

Deliverables:
- [x] API boundary document in `docs/architecture/BEAM_SERVICE_API_BOUNDARY.md`
- [x] response and error conventions documented in `docs/reference/BEAM_HTTP_API_CONTRACT.md`
- [x] first route inventory in `beam/apps/dg_web/lib/`

Acceptance Criteria:
- [x] public routes, request envelopes, and error codes are defined clearly enough that endpoint work does not drift by team or feature
- [x] transport-level conventions preserve the semantic guarantees already frozen in the Python reference
- [x] versioning rules are explicit enough to support future incompatible changes deliberately rather than accidentally

## Workstream 2 - Ingestion and Read APIs

Goal:
- expose the platform's core write and investigation surfaces safely

Tasks:
- [x] implement event ingestion endpoints for append-only writes
- [x] implement trace read endpoints for timeline, summary, and event payload access
- [x] implement context graph query endpoints
- [x] implement precedent search and retrieval endpoints
- [x] implement projection health endpoints for lag, cursor, and digest state
- [x] define streaming or polling behavior for clients that need near-real-time updates
- [x] ensure endpoint semantics preserve store and projector ordering guarantees

Deliverables:
- [x] controllers or API handlers for ingestion and read paths in `beam/apps/dg_web/`
- [x] service modules in `beam/apps/dg_api/`
- [x] request/response tests under `beam/apps/dg_web/test/`

Acceptance Criteria:
- [x] clients can append events and retrieve trace, graph, precedent, and projection health data through stable endpoints
- [x] read responses are ordered and filtered deterministically enough to match documented store and projection guarantees
- [x] endpoint behavior is covered by integration tests that run against real service and database components

## Workstream 3 - Admin, Auth, and Tenant Controls

Goal:
- make powerful endpoints safe enough for real operators and customers

Tasks:
- [x] implement service-account authentication for API clients
- [x] implement tenant-aware authorization rules
- [x] implement replay and rebuild admin endpoints with strong safeguards
- [x] add rate limiting and abuse protection on write and search surfaces
- [x] define audit logging for sensitive admin actions
- [x] define environment-level and tenant-level permissions for operator actions
- [x] document threat boundaries for public versus internal endpoints

Deliverables:
- [x] auth and authorization modules under `beam/apps/dg_api/`
- [x] protected admin surface in `beam/apps/dg_web/`
- [x] auth and admin security notes in `docs/operations/API_SECURITY.md`

Acceptance Criteria:
- [x] unauthorized users and cross-tenant callers are blocked consistently across public and admin routes
- [x] replay and rebuild controls require stronger authorization than ordinary read paths
- [x] rate limiting and audit capture are in place for the highest-risk write and admin operations

## Workstream 4 - Documentation, SDK Alignment, and Compatibility

Goal:
- make the service usable without reverse-engineering the code

Tasks:
- [x] generate OpenAPI documentation for the public API surface
- [x] document service boot, auth setup, and common request flows
- [x] define compatibility expectations between the Python library and the network API
- [x] decide which Python helper layers should call the service versus local storage
- [x] document API deprecation and backward-compatibility rules
- [x] add example client flows for ingestion, trace investigation, and replay status checks

Deliverables:
- [x] OpenAPI output checked into docs or generated artifacts
- [x] service usage guide in `docs/api/BEAM_SERVICE_API.md`
- [x] compatibility guidance in `docs/reference/PYTHON_SDK_SERVICE_COMPATIBILITY.md`

Acceptance Criteria:
- [x] external consumers can discover the public API shape without reading source code
- [x] Python users can understand when to use the service versus the local library path
- [x] compatibility and deprecation rules are explicit enough to support stable downstream adoption

## Workstream 5 - End-to-End Validation and Operability

Goal:
- prove the service is stable enough for real consumers

Tasks:
- [x] add end-to-end tests that exercise API writes through projectors into query endpoints
- [x] test real Postgres-backed flows with authenticated clients
- [x] test replay and admin controls through the HTTP surface
- [x] test auth failures, rate limits, and tenant boundary enforcement
- [x] add baseline API latency and throughput measurements
- [x] document service startup, configuration, and smoke-test commands
- [x] define readiness and liveness expectations for deployment environments

Deliverables:
- [x] end-to-end service suite under `beam/apps/dg_web/test/` or umbrella integration tests
- [x] performance notes in `docs/benchmarks/PHASE_5_API_BASELINE.md`
- [x] operator startup guide in `docs/operations/API_RUNTIME.md`

Acceptance Criteria:
- [x] end-to-end tests prove the write-to-projection-to-read path under authenticated service usage
- [x] startup and readiness guidance is good enough that operators can stand up and smoke-test the service reliably
- [x] baseline latency and throughput measurements exist for future regression comparison

## Reference Inputs

Phase 5 must stay aligned with these existing reference assets:

- `docs/reference/EVENT_ENVELOPE_CONTRACT.md`
- `docs/reference/APPEND_SEMANTICS.md`
- `docs/reference/PRECEDENT_AND_GRAPH_QUERY_SEMANTICS.md`
- `docs/reference/QUERY_AND_ORDERING_INVARIANTS.md`
- `docs/reference/SEMANTIC_PARITY_POLICY.md`

The network service must preserve the same semantic guarantees even if transport and auth layers add new concerns.

## Validation

Phase 5 should be validated with:

- authenticated end-to-end API tests against real Postgres and projector workers
- contract tests for request envelopes, error codes, and route behavior
- auth and tenant-isolation tests for both read and admin paths
- baseline latency and throughput measurements for the main API flows

## Required Evidence

Phase 5 should not be accepted without:

- a generated or checked-in OpenAPI artifact for the public surface
- end-to-end service tests proving write and read workflows
- documented auth, admin, and tenant boundary rules in `docs/operations/API_SECURITY.md`
- benchmark notes in `docs/benchmarks/PHASE_5_API_BASELINE.md`

## Exit Criteria

Phase 5 is complete only when:

- [x] external systems can write events through authenticated APIs
- [x] trace, graph, precedent, and projection health queries are available through stable endpoints
- [x] replay and rebuild controls are exposed with strong operator safeguards
- [x] auth, tenant isolation, and rate limiting are credible enough for shared environments
- [x] OpenAPI and service usage docs are good enough for outside consumers
- [x] end-to-end tests prove the service path works from write through projection-backed reads

## Recommended Execution Order

1. API surface and contract design
2. ingestion and read endpoints
3. auth, admin safeguards, and tenant rules
4. OpenAPI, docs, and SDK alignment
5. end-to-end validation and operability hardening

## Immediate Next Actions

- [x] write the HTTP route inventory and versioning plan
- [x] implement the first authenticated ingestion endpoint
- [x] implement the first trace read endpoint backed by Elixir projections
- [x] add the initial auth plug and service-account flow
- [x] add a first end-to-end API test against real Postgres and projector workers

## Notes

Rules for this phase:

- do not expose replay controls publicly without explicit authorization boundaries
- do not invent HTTP semantics that drift from the frozen reference contracts
- keep `dg_api` focused on service logic and keep Phoenix delivery thin where possible
- prefer explicit, boring API contracts over clever but unstable endpoint design
