"""Generate a sample SQLite DB from golden fixtures."""

from __future__ import annotations

import argparse
from pathlib import Path

from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.testing.golden import load_fixture


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate sample DecisionGraph DB")
    parser.add_argument(
        "--fixtures",
        type=Path,
        default=Path("tests") / "golden",
        help="Path to golden fixtures directory",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("sample.db"),
        help="Output SQLite DB path",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite output if it exists",
    )

    args = parser.parse_args()
    fixtures_dir: Path = args.fixtures
    output: Path = args.output

    if output.exists():
        if not args.force:
            raise SystemExit(f"Output file exists: {output} (use --force to overwrite)")
        output.unlink()

    if not fixtures_dir.exists():
        raise SystemExit(f"Fixtures directory not found: {fixtures_dir}")

    store = SQLiteEventStore(str(output))
    projector = SQLiteProjector(store.connection)

    for fixture_dir in sorted(fixtures_dir.iterdir()):
        if not (fixture_dir / "events.json").exists():
            continue
        fixture = load_fixture(fixture_dir)
        for envelope in fixture.events:
            store.append_event(envelope)

    projector.rebuild()
    projector.project_events(store.list_events())
    store.close()

    print(f"Sample DB created at {output}")


if __name__ == "__main__":
    main()
