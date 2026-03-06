"""Checks that the checked-in reference fixture bundle stays current."""

from __future__ import annotations

import json
from pathlib import Path

from decisiongraph.testing.golden import build_fixture_bundle, load_all_fixtures

FIXTURES_DIR = Path(__file__).parent.parent / "golden"
BUNDLE_PATH = FIXTURES_DIR / "reference_fixture_bundle.json"


def test_checked_in_reference_fixture_bundle_matches_fixtures() -> None:
    expected = build_fixture_bundle(load_all_fixtures(FIXTURES_DIR))
    actual = json.loads(BUNDLE_PATH.read_text(encoding="utf-8"))

    assert actual == expected
