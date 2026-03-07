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
- [ ] Phase 5 active

Phase complete:
- [ ] Phase 5 complete

## Dependencies

Phase 5 depends on these earlier checkpoints:

- [x] Phase 0 direction and scope are frozen
- [x] Phase 1 semantic reference is frozen
- [x] Phase 2 Elixir umbrella foundation is in place
- [x] Phase 3 BEAM event store is in place
- [ ] Phase 4 projection runtime is complete enough for service use
- [ ] Phase 5 execution is approved and started

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
- [ ] define the public API domains: ingestion, traces, graph, precedents, health, and admin
- [ ] decide which logic lives in `dg_api` versus Phoenix controllers and plugs
- [ ] define request and response envelope conventions
- [ ] define error response shape and stable error codes
- [ ] define pagination, filtering, and sorting conventions across endpoints
- [ ] define versioning strategy for the public HTTP surface

Deliverables:
- [ ] API boundary document in `docs/architecture/BEAM_SERVICE_API_BOUNDARY.md`
- [ ] response and error conventions documented in `docs/reference/BEAM_HTTP_API_CONTRACT.md`
- [ ] first route inventory in `beam/apps/dg_web/lib/`

Acceptance Criteria:
- [ ] public routes, request envelopes, and error codes are defined clearly enough that endpoint work does not drift by team or feature
- [ ] transport-level conventions preserve the semantic guarantees already frozen in the Python reference
- [ ] versioning rules are explicit enough to support future incompatible changes deliberately rather than accidentally

## Workstream 2 - Ingestion and Read APIs

Goal:
- expose the platform's core write and investigation surfaces safely

Tasks:
- [ ] implement event ingestion endpoints for append-only writes
- [ ] implement trace read endpoints for timeline, summary, and event payload access
- [ ] implement context graph query endpoints
- [ ] implement precedent search and retrieval endpoints
- [ ] implement projection health endpoints for lag, cursor, and digest state
- [ ] define streaming or polling behavior for clients that need near-real-time updates
- [ ] ensure endpoint semantics preserve store and projector ordering guarantees

Deliverables:
- [ ] controllers or API handlers for ingestion and read paths in `beam/apps/dg_web/`
- [ ] service modules in `beam/apps/dg_api/`
- [ ] request/response tests under `beam/apps/dg_web/test/`

Acceptance Criteria:
- [ ] clients can append events and retrieve trace, graph, precedent, and projection health data through stable endpoints
- [ ] read responses are ordered and filtered deterministically enough to match documented store and projection guarantees
- [ ] endpoint behavior is covered by integration tests that run against real service and database components

## Workstream 3 - Admin, Auth, and Tenant Controls

Goal:
- make powerful endpoints safe enough for real operators and customers

Tasks:
- [ ] implement service-account authentication for API clients
- [ ] implement tenant-aware authorization rules
- [ ] implement replay and rebuild admin endpoints with strong safeguards
- [ ] add rate limiting and abuse protection on write and search surfaces
- [ ] define audit logging for sensitive admin actions
- [ ] define environment-level and tenant-level permissions for operator actions
- [ ] document threat boundaries for public versus internal endpoints

Deliverables:
- [ ] auth and authorization modules under `beam/apps/dg_api/`
- [ ] protected admin surface in `beam/apps/dg_web/`
- [ ] auth and admin security notes in `docs/operations/API_SECURITY.md`

Acceptance Criteria:
- [ ] unauthorized users and cross-tenant callers are blocked consistently across public and admin routes
- [ ] replay and rebuild controls require stronger authorization than ordinary read paths
- [ ] rate limiting and audit capture are in place for the highest-risk write and admin operations

## Workstream 4 - Documentation, SDK Alignment, and Compatibility

Goal:
- make the service usable without reverse-engineering the code

Tasks:
- [ ] generate OpenAPI documentation for the public API surface
- [ ] document service boot, auth setup, and common request flows
- [ ] define compatibility expectations between the Python library and the network API
- [ ] decide which Python helper layers should call the service versus local storage
- [ ] document API deprecation and backward-compatibility rules
- [ ] add example client flows for ingestion, trace investigation, and replay status checks

Deliverables:
- [ ] OpenAPI output checked into docs or generated artifacts
- [ ] service usage guide in `docs/api/BEAM_SERVICE_API.md`
- [ ] compatibility guidance in `docs/reference/PYTHON_SDK_SERVICE_COMPATIBILITY.md`

Acceptance Criteria:
- [ ] external consumers can discover the public API shape without reading source code
- [ ] Python users can understand when to use the service versus the local library path
- [ ] compatibility and deprecation rules are explicit enough to support stable downstream adoption

## Workstream 5 - End-to-End Validation and Operability

Goal:
- prove the service is stable enough for real consumers

Tasks:
- [ ] add end-to-end tests that exercise API writes through projectors into query endpoints
- [ ] test real Postgres-backed flows with authenticated clients
- [ ] test replay and admin controls through the HTTP surface
- [ ] test auth failures, rate limits, and tenant boundary enforcement
- [ ] add baseline API latency and throughput measurements
- [ ] document service startup, configuration, and smoke-test commands
- [ ] define readiness and liveness expectations for deployment environments

Deliverables:
- [ ] end-to-end service suite under `beam/apps/dg_web/test/` or umbrella integration tests
- [ ] performance notes in `docs/benchmarks/PHASE_5_API_BASELINE.md`
- [ ] operator startup guide in `docs/operations/API_RUNTIME.md`

Acceptance Criteria:
- [ ] end-to-end tests prove the write-to-projection-to-read path under authenticated service usage
- [ ] startup and readiness guidance is good enough that operators can stand up and smoke-test the service reliably
- [ ] baseline latency and throughput measurements exist for future regression comparison

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

- [ ] external systems can write events through authenticated APIs
- [ ] trace, graph, precedent, and projection health queries are available through stable endpoints
- [ ] replay and rebuild controls are exposed with strong operator safeguards
- [ ] auth, tenant isolation, and rate limiting are credible enough for shared environments
- [ ] OpenAPI and service usage docs are good enough for outside consumers
- [ ] end-to-end tests prove the service path works from write through projection-backed reads

## Recommended Execution Order

1. API surface and contract design
2. ingestion and read endpoints
3. auth, admin safeguards, and tenant rules
4. OpenAPI, docs, and SDK alignment
5. end-to-end validation and operability hardening

## Immediate Next Actions

- [ ] write the HTTP route inventory and versioning plan
- [ ] implement the first authenticated ingestion endpoint
- [ ] implement the first trace read endpoint backed by Elixir projections
- [ ] add the initial auth plug and service-account flow
- [ ] add a first end-to-end API test against real Postgres and projector workers

## Notes

Rules for this phase:

- do not expose replay controls publicly without explicit authorization boundaries
- do not invent HTTP semantics that drift from the frozen reference contracts
- keep `dg_api` focused on service logic and keep Phoenix delivery thin where possible
- prefer explicit, boring API contracts over clever but unstable endpoint design
