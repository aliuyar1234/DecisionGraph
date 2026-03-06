# Semantic Baseline Release Notes

## Checkpoint

Chosen baseline checkpoint form:

- annotated git tag only

Chosen tag name:

- `semantic-reference-python-v1`

A release branch is not required for this checkpoint.

## What The Baseline Freezes

- Phase 0 direction and architecture docs
- the Phase 1 reference docs under `docs/reference`
- the checked-in fixture bundle at `tests/golden/reference_fixture_bundle.json`
- the golden scenario corpus:
  - `renewal`
  - `support`
  - `dealdesk`
  - `release_rejected`
  - `sync_failure`

## Why This Baseline Exists

The baseline gives future BEAM work a precise parity target before Phoenix, OTP runtime, or service work expands the system.

## Review Rule For Future Semantic Changes

Any future semantic change must:

1. call out the change explicitly in review
2. update the relevant reference docs
3. update or add affected golden fixtures
4. regenerate the checked-in fixture bundle
5. update parity-oriented tests
6. record the new baseline or delta in release notes

## Immediate Success Condition

Once the baseline tag exists, a future Elixir implementation can say something concrete:

- matches `semantic-reference-python-v1`
- differs from it in approved, documented ways
