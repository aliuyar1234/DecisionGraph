# Post Release Backlog

## Purpose

This document holds the prioritized follow-up backlog created from Phase 10 early adopter feedback and the post-release review.

It is intentionally higher signal than a raw issue dump.

## Priority Buckets

### Must Address Soon

- [x] Post-release maintainability and contributor-experience pass
  - [x] Split oversized modules without weakening the current public contracts:
    - `beam/apps/dg_web/lib/decision_graph_web/live/dashboard_live.ex`
    - `beam/apps/dg_api/lib/decision_graph/api/console.ex`
    - `beam/apps/dg_store/lib/decision_graph/store.ex`
    - `src/decisiongraph/api.py`
  - [x] Make fresh-checkout setup and testing smoother for contributors:
    - document one obvious Python dev path with test dependencies included
    - keep the BEAM test-database bootstrap path short and explicit
    - add lightweight smoke or verification commands for both implementation surfaces
  - [x] Keep tightening docs, demos, and release packaging:
    - add more screenshot, walkthrough, and demo-support assets for the seeded operator-console path
    - keep install, validation, and packaging docs aligned to the exact supported source-first workflow
    - keep the tagged release workflow validating the packaged OTP release and Docker image paths
  - [x] Keep parity coverage strong as the BEAM runtime grows:
    - extend shared golden-fixture and parity checks whenever frozen-core BEAM behavior changes
    - classify any semantic drift explicitly instead of allowing silent divergence
- [x] Publish signed tagged OTP release artifacts from the release workflow
- [x] Publish a prebuilt container image from the repo Dockerfile
- [x] Add a first-run UI bootstrap and token-rotation management experience
- [x] Add quieter release-validator output modes or a generated human-readable summary page beside the JSON artifacts

### Next Release Candidates

- [x] Add a BEAM demo screenshot pack or walkthrough asset set for docs and release notes
- [x] Add a staging-safe validation mode that exercises production-like configs without reseeding the demo tenant
- [x] Add a Python service client path that is explicit and documented without weakening the current semantic-authority split
- [x] Add automated documentation snippet coverage for the BEAM install and demo commands

### Later Opportunities

- [ ] Packaged installers beyond source checkout
- [ ] Multi-node or clustered deployment work if product direction changes
- [ ] Richer import flows for turning real customer-like data into demo or evaluation tenants
- [ ] Broader operator onboarding and guided console tours

## Intake Rules

Add items here when they are:

- confirmed by early adopter feedback
- confirmed by post-release review
- clearly out of scope for the first serious release but worth retaining

Do not use this file for speculative ideas with no product signal behind them.
