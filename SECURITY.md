# Security Policy

## Supported Versions

Security fixes are provided for:

- Latest `1.x` release line (after v1.0 is cut)
- `master` branch (pre-v1 development)

Older unsupported branches may not receive fixes.

## Reporting a Vulnerability

Please do not open public issues for undisclosed vulnerabilities.

Report privately via:

- GitHub Security Advisories (preferred)
- Repository owner contact listed in GitHub profile

Include:

- Affected version/commit
- Reproduction steps or proof-of-concept
- Impact assessment
- Suggested mitigations (if available)

## Response Targets

- Initial triage acknowledgment: within 72 hours
- Severity assessment and remediation plan: within 7 days
- Coordinated disclosure timeline: agreed with reporter before public release

## Disclosure

- Fixes are released with changelog notes.
- Credit is given to reporters unless anonymity is requested.

## Secret Scanning Baseline Policy

- Repository secret scanning uses `.secrets.baseline` for known false positives in test/spec fixtures.
- Any new baseline entry requires explicit review in pull requests.
- Real credentials must never be added to the baseline; rotate and remove them immediately.
- CI fails if secret scan results would modify `.secrets.baseline` unexpectedly.
