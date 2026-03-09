# Release Policy and Readiness

## Purpose

This page defines the first-release policy for DecisionGraph's local-first self-hosted platform.

It answers:

- how versions should move
- what evidence blocks or allows a release
- who signs off
- how first-release support and hotfixes work

## Release Model

DecisionGraph's first serious platform release is:

- GitHub-downloadable
- self-hosted
- source-first
- single-node

The supported operational posture is the same one defined during Phase 8:

- source checkout
- BEAM umbrella under `beam/`
- packaged OTP release built from `mix release decisiongraph_beam`
- signed packaged OTP release tarball attached by the tagged release workflow
- tagged GHCR image built from `beam/Dockerfile`
- repo-provided container build via `beam/Dockerfile`
- optional source-building container path via `beam/Dockerfile.build`
- repository `docker-compose.yml` for Postgres and optional OTEL
- operator docs and runbooks under `docs/`

This release policy does not assume:

- hosted SaaS operation
- clustered multi-node runtime packaging

## Versioning Policy

DecisionGraph uses semantic versioning for the release tag and user-facing compatibility expectations.

Release tags should follow:

- `vMAJOR.MINOR.PATCH`

Versioning rules:

- `PATCH` is for safe fixes, docs corrections, and low-risk operational polish
- `MINOR` is for backward-compatible feature additions, new docs, and additive release assets
- `MAJOR` is required for semantic authority changes, destructive removals, incompatible API defaults, or materially changed deployment assumptions

Compatibility-sensitive rules:

- Python local constructors must not silently change execution mode in a patch or minor release
- BEAM API behavior should remain backward-compatible within the current major version unless explicitly documented otherwise
- workflow and operator behavior may grow additively in minor releases, but not by silently weakening determinism or audit guarantees
- destructive migration expectations require a major release or an explicitly documented exceptional migration policy

## Schema Migration Policy

Migration rules for the first release posture:

- pre-upgrade backup is mandatory before applying schema changes
- patch releases should avoid destructive schema changes
- minor releases may add forward migrations if rollback guidance is explicit
- destructive rollback by partially undoing migrations is not supported; rollback means restoring backup plus previous release
- self-hosted operators must have a clean restore path before starting an upgrade

## Release Quality Gates

Release is blocked until every item is complete:

- required CI workflows are green:
  - `ci.yml`
  - `beam.yml`
  - `demo.yml`
  - `docs.yml`
  - `security.yml`
- deterministic parity evidence remains green for the frozen core
- self-hosted release checklist is reviewed:
  - `docs/operations/SELF_HOSTED_RELEASE_CHECKLIST.md`
- install, upgrade, backup, restore, and restart drills have current validation notes
- authenticated service E2E and projector recovery coverage pass
- demo smoke checks and docs snippet checks pass
- BEAM install and demo docs snippet checks pass
- README, showcase, and release-facing docs are updated for the candidate release
- no open critical or high security issue remains untriaged for the release decision
- release notes, migration notes, and known limitations are prepared
- release artifacts are verified before publishing
- `mix dg.release.validate --output ../.tmp/phase10-release-validation.json` passes for the supported source-first topology
- `mix release decisiongraph_beam` succeeds for the candidate
- `docker build -f beam/Dockerfile -t decisiongraph-beam:release beam/_build/prod/rel` succeeds for the candidate after the release is built

## Release Evidence Package

Each serious release should have an evidence package covering:

- version and release tag
- validation commands that were run
- supported topology used for release validation
- migration and backup expectations
- known limitations and unsupported topologies
- sign-off record

The minimum launch-readiness surface is split across:

- this page
- `docs/operations/SELF_HOSTED_RELEASE_CHECKLIST.md`
- `docs/benchmarks/PHASE_10_RELEASE_VALIDATION.md`
- release notes for the candidate tag

## Sign-Off Roles

Each release should have explicit sign-off, even if one maintainer fills multiple roles.

Required roles:

- release owner
- runtime owner
- reference or parity owner
- docs or showcase owner

Required sign-off questions:

- is the release technically safe enough to ship
- is the install and upgrade story honest and reproducible
- are determinism and parity guarantees still credible
- are known limitations documented clearly enough not to mislead users

## Support Expectations

The first serious release should present support honestly:

- support is self-hosted and community-oriented, not SLA-backed
- GitHub issues and discussions are the default feedback and support channels
- documentation is the first-line support surface
- first-release users should expect best-effort response rather than guaranteed response windows

## Security Response and Hotfix Policy

Security and critical-operational issues should follow this rule set:

- critical security or data-integrity issues can justify an expedited patch release
- hotfix releases must still preserve backup, rollback, and migration guidance
- release notes must call out urgent operator actions clearly
- if a candidate release weakens determinism, idempotency, ordering, or replay guarantees, the release should be blocked instead of papered over with messaging

## V1.0 Release Checklist

Release is blocked until every item below is complete:

- CI green for required workflows
- parity, recovery, and service validation evidence current
- docs snippet and demo smoke checks passing with artifacts attached
- BEAM docs snippet smoke checks passing with artifacts attached
- migration compatibility and determinism suites passing
- Phase 10 release validation artifact captured for the current candidate
- no open critical or high security findings without explicit sign-off
- README, showcase, and release docs updated for the release candidate
- version bumped in package metadata where applicable
- signed git tag created
- release artifacts verified before publish
- self-hosted upgrade and rollback runbook reviewed against the target release
- pre-upgrade backup procedure confirmed for the target deployment
- self-hosted release checklist reviewed:
  - `docs/operations/SELF_HOSTED_RELEASE_CHECKLIST.md`

## Deprecation Policy

DecisionGraph uses a conservative deprecation lifecycle:

1. Introduce deprecation warning in a `MINOR` release.
2. Document migration path and examples.
3. Keep old behavior for at least one full minor cycle.
4. Remove only in next `MAJOR` release.

For v1, removals are not allowed in `PATCH`/`MINOR` releases.

## Known Limitations Requirement

Every serious release should publish current limitations for:

- unsupported deployment topologies
- packaging that does not yet exist
- beta or early adopter sharp edges that are still acceptable
- release-follow-up items that are intentionally deferred

Use:

- `docs/operations/FIRST_RELEASE_LIMITATIONS.md`

## Phase 10 Release Candidate Evidence

The current BEAM release path now has two concrete evidence artifacts:

- `.tmp/phase10-demo-report.json`
- `.tmp/phase10-release-validation.json`

And three concrete packaging paths:

- `mix release decisiongraph_beam`
- `beam/Dockerfile`
- `beam/Dockerfile.build`

The first recorded successful run is summarized in:

- `docs/benchmarks/PHASE_10_RELEASE_VALIDATION.md`

The tagged release workflow in `.github/workflows/release.yml` now uploads the validation artifacts and the packaged BEAM release tarball to the GitHub release record after both the Python and BEAM preflight jobs pass.

## Migration Notes: Unreleased

### Summary
- Added typed `DecisionGraph` helper methods for common event writes.
- Added projection health inspection via `DecisionGraph.get_projection_health()` and `python -m decisiongraph projection-status`.
- Made `python -m decisiongraph replay` fully read-only while improving projection replay/sync batching and precedent indexing.

### Impact
- Existing `append_event()` workflows remain supported; the new write helpers are convenience APIs.
- Projection-backed operators now have a stable health surface for lag and digest inspection.
- Existing writable databases pick up the structured precedent index through migration `0005`.

### Required Actions
1. Apply the current migrations before relying on the structured precedent index on existing databases.
2. Optionally adopt the typed helper methods in application code for stronger payload ergonomics.
3. Optionally add `projection-status` or `get_projection_health(include_digests=True)` to recovery and monitoring workflows.

### Verification
- `python -m decisiongraph projection-status <db>`
- `python -m decisiongraph projection-status <db> --include-digests`
- `python -m decisiongraph replay <db>`
- self-hosted upgrade verification should also follow `docs/operations/UPGRADE_AND_ROLLBACK.md`

### Rollback
- Continue using `append_event()` if you do not want to adopt the new helper APIs yet.
- Restore the previous release if you need the old precedent index schema or the old `replay` behavior.

## Release Notes Template

Use this template for every serious release:

```markdown
# DecisionGraph <version>

## Highlights
- One-line summary of the release.

## Supported Self-Hosted Topology
- What was validated for this release.

## Migration Notes
- Link or embed the migration section.

## Known Limitations
- Link to `docs/operations/FIRST_RELEASE_LIMITATIONS.md`.

## Validation
- Commands and checks run for the release candidate.

## Rollback Reminder
- Backup before upgrade.
- Restore backup plus previous release if verification fails.
```

## Migration Notes Template

Use this template for every change that affects operators or integrators:

```markdown
## Migration Notes: <version>

### Summary
- One-line statement of what changed.

### Impact
- Who is affected.
- Backward compatibility status.

### Required Actions
1. Step 1
2. Step 2

### Verification
- Command(s) to verify migration succeeded.

### Rollback
- Exact rollback steps if verification fails.
```
