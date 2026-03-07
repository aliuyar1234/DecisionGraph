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
- there is no guaranteed prebuilt published app container image, even though the repo now ships `beam/Dockerfile` and `beam/Dockerfile.build`
- there is no guaranteed prebuilt published OTP release asset, even though the repo now supports `mix release decisiongraph_beam`
- clustered multi-node deployment is not a supported release path
- Python remains the semantic reference and local embedded surface; there is no full Python service client yet
- first-release support is best-effort and community-oriented, not SLA-backed
- the first polished demo path is a seeded synthetic dataset under tenant `release-demo`, not imported customer data
- service-account bootstrap is CLI-driven and file-driven; there is no first-run UI wizard yet
- release validation evidence is generated from command-driven JSON artifacts, not from an interactive installer bundle
- development tokens exist for local evaluation and must not be reused for any network-exposed deployment

## Release-Specific Notes

For the `v0.1.0` release candidate:

- the strongest supported path is still local or nearby Postgres with a source checkout under `beam/`
- the seeded showcase intentionally creates overdue and escalated workflows so the operator console is immediately interesting
- release-candidate validation uses tenant `release-demo` and writes evidence to `.tmp/phase10-demo-report.json` and `.tmp/phase10-release-validation.json`
- projection digest values inside those artifacts are candidate-specific evidence and can change across repeated runs against a long-lived development database

## Update Rule

Update this file whenever:

- a limitation becomes newly important for release messaging
- a previously unsupported path becomes supported
- early adopter feedback reveals a sharp edge that is acceptable for release but must be disclosed
