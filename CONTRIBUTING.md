# Contributing

Thanks for your interest in improving DecisionGraph!

## Development setup

```bash
uv sync --extra dev --extra postgres
```

That gives you the Python dev tools plus local PostgreSQL support for parity and integration work.

## Fresh checkout: Python surface

```bash
uv run ruff check src demo scripts tests
uv run mypy src
uv run lint-imports
uv run pytest -q
uv run python scripts/demo_smoke_check.py --artifact-dir .tmp/demo-smoke
uv run python scripts/docs_snippets_check.py --artifact-dir .tmp/docs-snippets
```

## Fresh checkout: BEAM surface

Start the shared local services from the repository root:

```bash
docker compose up postgres otel-collector -d
```

Then, from `beam/`:

```bash
mix setup
mix do --app dg_store ecto.setup
mix test
python ../scripts/beam_docs_snippets_check.py --artifact-dir ../.tmp/beam-docs-snippets
```

## Run checks

```bash
uv run ruff check src
uv run mypy src
uv run lint-imports
uv run pytest
```

```bash
cd beam
mix format --check-formatted
mix credo --strict
mix test
mix dialyzer
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
3. GitHub Actions runs the Python and BEAM release preflight suites, writes JSON and Markdown validation evidence, signs the packaged BEAM OTP tarball, publishes the GitHub Release, and publishes the tagged GHCR image.
4. PyPI publishing remains conditional on trusted publisher configuration.

