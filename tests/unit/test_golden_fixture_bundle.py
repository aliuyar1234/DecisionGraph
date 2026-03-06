"""Tests for the exported semantic-reference fixture bundle."""

from __future__ import annotations

import json
from pathlib import Path

from decisiongraph.testing.golden import (
    REFERENCE_FIXTURE_BUNDLE_FORMAT,
    REFERENCE_FIXTURE_BUNDLE_VERSION,
    build_fixture_bundle,
    export_fixture_bundle,
    load_all_fixtures,
)

FIXTURES_DIR = Path(__file__).parent.parent / "golden"


def test_build_fixture_bundle_shape() -> None:
    fixtures = load_all_fixtures(FIXTURES_DIR)

    bundle = build_fixture_bundle(fixtures)

    assert bundle["format"] == REFERENCE_FIXTURE_BUNDLE_FORMAT
    assert bundle["version"] == REFERENCE_FIXTURE_BUNDLE_VERSION
    assert bundle["scenario_count"] == len(fixtures)

    scenario_names = [scenario["scenario"] for scenario in bundle["scenarios"]]
    assert scenario_names == sorted(scenario_names)

    for scenario in bundle["scenarios"]:
        assert scenario["event_count"] == len(scenario["events"])
        assert scenario["event_type_sequence"] == [
            event["event_type"] for event in scenario["events"]
        ]
        assert list(scenario["expected_digests"]) == sorted(scenario["expected_digests"])
        assert scenario["projection_snapshot"]["projection_cursor"] == scenario["event_count"]
        assert scenario["projection_snapshot"]["trace_summary"]["trace_id"] == scenario["trace_id"]


def test_export_fixture_bundle_is_stable(tmp_path: Path) -> None:
    fixtures = load_all_fixtures(FIXTURES_DIR)
    first_path = tmp_path / "bundle-a.json"
    second_path = tmp_path / "bundle-b.json"

    export_fixture_bundle(fixtures, first_path)
    export_fixture_bundle(fixtures, second_path)

    first = first_path.read_text(encoding="utf-8")
    second = second_path.read_text(encoding="utf-8")

    assert first == second
    assert json.loads(first) == build_fixture_bundle(fixtures)
