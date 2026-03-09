# First Release Limitations

## Purpose

This document lists the limitations that remain acceptable for DecisionGraph's first serious self-hosted release.

The goal is honesty, not apology.

## Supported Shape

The first release is expected to support:

- local-first self-hosted operation
- source checkout from GitHub
- the BEAM umbrella under `beam/`
- Postgres as the primary shared-runtime store
- the repository `docker-compose.yml` for Postgres and optional OTEL support

## Known Limitations

- there is no hosted SaaS deployment path
- clustered multi-node deployment is not a supported release path
- Python remains the semantic reference and local embedded surface; the new HTTP service client is explicit and additive rather than a hidden execution-mode switch
- first-release support is best-effort and community-oriented, not SLA-backed
- the first polished demo path is a seeded synthetic dataset under tenant `release-demo`, not imported customer data
- service-account bootstrap persistence is still CLI-driven and file-driven; `/bootstrap` is a preview and rotation-planning surface, not a write-back admin panel
- release validation evidence is generated from command-driven JSON and Markdown artifacts, not from an interactive installer bundle
- development tokens exist for local evaluation and must not be reused for any network-exposed deployment

## Release-Specific Notes

For the `v0.1.0` release candidate:

- the strongest supported path is still local or nearby Postgres with a source checkout under `beam/`
- tagged releases can publish a signed OTP tarball plus a tagged GHCR image for the repo Dockerfile path
- the seeded showcase intentionally creates overdue and escalated workflows so the operator console is immediately interesting
- release-candidate validation uses tenant `release-demo` and writes evidence to `.tmp/phase10-demo-report.json`, `.tmp/phase10-release-validation.json`, and `.tmp/phase10-release-validation.md`
- projection digest values inside those artifacts are candidate-specific evidence and can change across repeated runs against a long-lived development database

## Update Rule

Update this file whenever:

- a limitation becomes newly important for release messaging
- a previously unsupported path becomes supported
- early adopter feedback reveals a sharp edge that is acceptable for release but must be disclosed
