# Post Release Backlog

## Purpose

This document holds the prioritized follow-up backlog created from Phase 10 early adopter feedback and the post-release review.

It is intentionally higher signal than a raw issue dump.

## Priority Buckets

### Must Address Soon

- publish signed tagged OTP release artifacts from the release workflow
- publish a prebuilt container image from the repo Dockerfile
- add a first-run UI bootstrap and token-rotation management experience
- add quieter release-validator output modes or a generated human-readable summary page beside the JSON artifacts

### Next Release Candidates

- add a BEAM demo screenshot pack or walkthrough asset set for docs and release notes
- add a staging-safe validation mode that exercises production-like configs without reseeding the demo tenant
- add a Python service client path that is explicit and documented without weakening the current semantic-authority split
- add automated documentation snippet coverage for the BEAM install and demo commands

### Later Opportunities

- packaged installers beyond source checkout
- multi-node or clustered deployment work if product direction changes
- richer import flows for turning real customer-like data into demo or evaluation tenants
- broader operator onboarding and guided console tours

## Intake Rules

Add items here when they are:

- confirmed by early adopter feedback
- confirmed by post-release review
- clearly out of scope for the first serious release but worth retaining

Do not use this file for speculative ideas with no product signal behind them.
