# Early Adopter Feedback

## Purpose

This document is the Phase 10 capture point for early adopter, dogfood, or pilot feedback before the first serious release.

Use it to record what real users or realistic internal stand-ins experienced on the supported self-hosted paths.

## Audience

Target feedback should come from one or more of:

- operators
- platform teams
- compliance or audit stakeholders
- agent builders using the Python reference or the BEAM runtime

## Feedback Log

Phase 10 used realistic internal dogfood sessions and release-candidate drills as the first early-adopter stand-ins for the self-hosted path.

### Session 1 - Fresh Self-Hosted Demo Bootstrap

- date:
  - `2026-03-07`
- release candidate:
  - `v0.1.0` working tree
- deployment path:
  - source-first BEAM runtime with repo `docker-compose.yml` Postgres
- user profile:
  - operator or platform evaluator stand-in
- goal:
  - go from clone to an impressive console state without reading source files
- friction:
  - there was no first-class BEAM demo seed path, so the operator showcase required tribal knowledge
- strongest positive signal:
  - once seeded, the console already felt like a real decision-operations product instead of a thin admin page
- follow-up action:
  - add `mix dg.demo.seed` and document the seeded `release-demo` routes

### Session 2 - Authenticated Release Validation Drill

- date:
  - `2026-03-07`
- release candidate:
  - `v0.1.0` working tree
- deployment path:
  - real HTTP runtime via `mix dg.release.validate`
- user profile:
  - platform or release owner stand-in
- goal:
  - prove the release path over authenticated HTTP, not only through direct module calls
- friction:
  - development reader and writer tokens were scoped only to `default`, which broke the isolated `release-demo` tenant path
- strongest positive signal:
  - the validator covered health, console load, trace read, workflow export, and replay round-trip in one repeatable command
- follow-up action:
  - authorize the development reader and writer tokens for both `default` and `release-demo`

### Session 3 - Repeated Workflow Validation And Reseed Safety

- date:
  - `2026-03-07`
- release candidate:
  - `v0.1.0` working tree
- deployment path:
  - repeated release demo seeding and workflow validation
- user profile:
  - workflow operator or release maintainer stand-in
- goal:
  - prove that reseeding and repeated validation did not create fragile runtime behavior
- friction:
  - workflow notifications and actions relied on `System.unique_integer()`-based identifiers that could collide with already-persisted records
- strongest positive signal:
  - the bug only appeared because the release-candidate drill used the real self-hosted path, which means the validation loop is surfacing the right class of problems
- follow-up action:
  - switch workflow action and notification identifiers to UUID-backed values

## Synthesis

Current synthesis:

- highest-signal onboarding gap:
  - the project needed a first-class BEAM demo seed path, not just a running server
- highest-signal runtime gap:
  - workflow runtime identifiers needed true globally unique persistence semantics
- product gap closed before release:
  - release validation is now a one-command path with JSON evidence output
- remaining deferred limitation:
  - the self-hosted release is still source-first, without a packaged OTP release or app container image

This document should continue growing after the first tagged release, but it already influenced the shipped Phase 10 shape instead of acting as a passive notes file.
