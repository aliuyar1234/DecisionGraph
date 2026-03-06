"""Export the checked-in cross-language semantic reference fixture bundle."""

from __future__ import annotations

import argparse
from pathlib import Path

from decisiongraph.testing.golden import export_fixture_bundle, load_all_fixtures


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Export the DecisionGraph semantic reference fixture bundle."
    )
    parser.add_argument(
        "--fixtures-dir",
        default="tests/golden",
        help="Directory containing golden fixture subdirectories.",
    )
    parser.add_argument(
        "--output",
        default="tests/golden/reference_fixture_bundle.json",
        help="Path to the generated bundle JSON file.",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    fixtures_dir = Path(args.fixtures_dir)
    output_path = Path(args.output)

    fixtures = load_all_fixtures(fixtures_dir)
    export_fixture_bundle(fixtures, output_path)
    print(output_path.as_posix())
    return 0


if __name__ == "__main__":  # pragma: no cover - script entrypoint
    raise SystemExit(main())
