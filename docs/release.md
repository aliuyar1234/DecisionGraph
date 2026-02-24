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

## Deprecation Policy

DecisionGraph uses a conservative deprecation lifecycle:

1. Introduce deprecation warning in a `MINOR` release.
2. Document migration path and examples.
3. Keep old behavior for at least one full minor cycle.
4. Remove only in next `MAJOR` release.

For v1, removals are not allowed in `PATCH`/`MINOR` releases.

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
