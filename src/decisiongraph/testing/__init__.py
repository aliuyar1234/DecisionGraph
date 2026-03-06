"""Testing utilities for DecisionGraph.

Provides InMemoryEventStore for unit tests and golden fixture utilities.
"""

from decisiongraph.testing.fakes import InMemoryEventStore, create_test_envelope
from decisiongraph.testing.golden import (
    REFERENCE_FIXTURE_BUNDLE_FORMAT,
    REFERENCE_FIXTURE_BUNDLE_VERSION,
    GoldenFixture,
    build_fixture_bundle,
    discover_fixture_dirs,
    event_envelope_to_dict,
    export_fixture_bundle,
    fixture_to_dict,
    load_all_fixtures,
    load_fixture,
)

__all__ = [
    "GoldenFixture",
    "InMemoryEventStore",
    "REFERENCE_FIXTURE_BUNDLE_FORMAT",
    "REFERENCE_FIXTURE_BUNDLE_VERSION",
    "build_fixture_bundle",
    "create_test_envelope",
    "discover_fixture_dirs",
    "event_envelope_to_dict",
    "export_fixture_bundle",
    "fixture_to_dict",
    "load_all_fixtures",
    "load_fixture",
]
