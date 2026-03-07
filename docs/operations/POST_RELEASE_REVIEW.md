# Post Release Review

## Purpose

This document is the Phase 10 landing zone for the first post-release review.

It also captures the final release-candidate review that immediately preceded the first public tag.

## Release Summary

- release tag:
  - `v0.1.0`
- release candidate reviewed:
  - `v0.1.0`
- review date:
  - `2026-03-07`
- supported topology validated:
  - one BEAM node, one PostgreSQL instance, optional OTEL collector, source-first checkout
- release evidence:
  - `docs/benchmarks/PHASE_10_RELEASE_VALIDATION.md`

## What Went Well

- the self-hosted BEAM runtime can now be validated end to end through one repeatable command
- the release demo seeds a console state that immediately shows precedent review, escalated workflows, and incident investigation
- the real release drill surfaced genuine runtime issues before release rather than after it

## Issues Observed

- the release demo originally lacked a first-class seed path
- development reader and writer tokens were originally scoped too narrowly for the dedicated demo tenant
- workflow notification and action identifiers were not globally safe across repeated process lifecycles until Phase 10 fixed them

## Early Signals

Capture:

- install success or failure themes
- upgrade or restore friction
- runtime or workflow issues reported first
- docs or demo misunderstandings

Current pre-release signals:

- the product feels much stronger when the first screen is a seeded live investigation rather than an empty shell
- the release path needs machine-readable evidence artifacts, not just prose checklists
- the self-hosted source-first posture is acceptable when the docs are explicit, but packaging expectations must stay honest

## Immediate Fixes

- added `mix dg.demo.seed`
- added `mix dg.release.validate`
- widened local evaluation auth scopes to cover `release-demo`
- changed workflow notification and action identifiers to UUID-backed values
- rewrote install, showcase, and release docs around the actual validated command path

## Follow-Up Backlog

Move durable follow-up items into:

- `docs/product/POST_RELEASE_BACKLOG.md`

## Decision

Conclude with:

- whether the release posture remains acceptable
- whether any hotfix is required
- whether the supported topology statement needs to change

Current decision:

- the release posture is acceptable for the documented source-first self-hosted topology
- no hotfix is required immediately after `v0.1.0`; the validated release path is acceptable as shipped
- the supported topology statement does not need to change; it needs to stay intentionally narrow
