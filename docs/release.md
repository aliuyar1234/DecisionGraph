# Release Checklist and Deprecation Policy

## V1.0 Release Checklist

Release is blocked until every item is complete:

- CI green for required workflows (`ci.yml`, `demo.yml`, docs build)
- Coverage gate passing
- Demo smoke checks passing with artifacts attached
- Migration compatibility and determinism suites passing
- No open critical/high security findings
- README/docs snippets validated
- Changelog updated for release tag
- Version bumped in package metadata
- Signed git tag created
- Release artifacts verified before publish
- Self-hosted upgrade and rollback runbook reviewed against the target release
- Pre-upgrade backup procedure confirmed for the target deployment
- Self-hosted release checklist reviewed: `docs/operations/SELF_HOSTED_RELEASE_CHECKLIST.md`

## Deprecation Policy

DecisionGraph uses a conservative deprecation lifecycle:

1. Introduce deprecation warning in a `MINOR` release.
2. Document migration path and examples.
3. Keep old behavior for at least one full minor cycle.
4. Remove only in next `MAJOR` release.

For v1, removals are not allowed in `PATCH`/`MINOR` releases.

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
