# Contributing

Thanks for your interest in improving DecisionGraph!

## Development setup

```bash
uv sync --extra dev
```

## Run checks

```bash
uv run ruff check src
uv run mypy src
uv run lint-imports
uv run pytest
```

## Pre-commit (optional but recommended)

```bash
uv run pre-commit install
```

## Docs

```bash
uv sync --extra docs
uv run mkdocs serve
```

## Commit style

We follow Conventional Commits (`feat:`, `fix:`, `docs:`, `ci:`, etc.) to enable
automatic release notes.

## Release process

1. Bump `version` in `pyproject.toml`.
2. Tag and push: `git tag vX.Y.Z && git push origin vX.Y.Z`.
3. GitHub Actions builds artifacts, creates a GitHub Release with auto-notes,
   and publishes to PyPI (requires PyPI trusted publisher configuration).

