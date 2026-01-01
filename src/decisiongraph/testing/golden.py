"""Golden fixture utilities for E2E testing per SSOT P6.

This module provides utilities for loading, replaying, and validating
golden fixtures based on the scenarios in SSOT Section 10.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from decisiongraph.domain.events import EventEnvelope
from decisiongraph.domain.types import ActorRef, SourceRef
from decisiongraph.projections.digests import (
    compute_context_graph_digest,
    compute_full_projection_digest,
    compute_precedent_index_digest,
    compute_trace_summary_digest,
)
from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.storage.sqlite import SQLiteEventStore


@dataclass(frozen=True)
class GoldenFixture:
    """Golden fixture with scenario metadata and events.

    Attributes:
        scenario: Scenario name (e.g., "renewal", "support", "dealdesk")
        ssot_reference: Reference to SSOT section (e.g., "10.1")
        description: Human-readable description
        trace_id: Primary trace ID for this scenario
        events: List of event envelopes
        expected_digests: Expected projection digests
    """

    scenario: str
    ssot_reference: str
    description: str
    trace_id: str
    events: list[EventEnvelope]
    expected_digests: dict[str, str]


def load_fixture(fixture_dir: Path) -> GoldenFixture:
    """Load golden fixture from directory.

    Reads events.json and expected_digest.txt from the fixture directory.

    Args:
        fixture_dir: Path to fixture directory (e.g., tests/golden/renewal/)

    Returns:
        GoldenFixture with loaded events and expected digests

    Raises:
        FileNotFoundError: If events.json or expected_digest.txt is missing
        ValueError: If JSON is malformed or events are invalid
    """
    events_path = fixture_dir / "events.json"
    digest_path = fixture_dir / "expected_digest.txt"

    if not events_path.exists():
        raise FileNotFoundError(f"Missing events.json in {fixture_dir}")
    if not digest_path.exists():
        raise FileNotFoundError(f"Missing expected_digest.txt in {fixture_dir}")

    # Load events JSON
    with open(events_path, encoding="utf-8") as f:
        data = json.load(f)

    # Load expected digests
    expected_digests: dict[str, str] = {}
    with open(digest_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if ":" not in line:
                raise ValueError(f"Invalid digest line: {line}")
            key, value = line.split(":", 1)
            expected_digests[key] = value

    # Convert events to EventEnvelope objects
    events: list[EventEnvelope] = []
    for event_dict in data["events"]:
        envelope = envelope_from_dict(event_dict)
        events.append(envelope)

    return GoldenFixture(
        scenario=data["scenario"],
        ssot_reference=data["ssot_reference"],
        description=data["description"],
        trace_id=data["trace_id"],
        events=events,
        expected_digests=expected_digests,
    )


def envelope_from_dict(event_dict: dict[str, Any]) -> EventEnvelope:
    """Convert event dict to EventEnvelope.

    Args:
        event_dict: Event dictionary from JSON

    Returns:
        EventEnvelope instance
    """
    # Convert source dict to SourceRef
    source_dict = event_dict["source"]
    source = SourceRef(
        producer_id=source_dict["producer_id"],
        system=source_dict["system"],
        subsystem=source_dict.get("subsystem"),
    )

    # Convert actor dict to ActorRef
    actor_dict = event_dict["actor"]
    actor = ActorRef(
        actor_type=actor_dict["actor_type"],
        actor_id=actor_dict["actor_id"],
    )

    return EventEnvelope(
        event_id=event_dict["event_id"],
        trace_id=event_dict["trace_id"],
        trace_seq=event_dict["trace_seq"],
        event_type=event_dict["event_type"],
        occurred_at=event_dict["occurred_at"],
        source=source,
        actor=actor,
        correlation_id=event_dict.get("correlation_id"),
        causation_event_id=event_dict.get("causation_event_id"),
        idempotency_key=event_dict["idempotency_key"],
        schema_version=event_dict.get("schema_version", 1),
        payload=event_dict["payload"],
        tags=event_dict.get("tags", []),
    )


def replay_fixture(fixture: GoldenFixture) -> dict[str, str]:
    """Replay fixture events and compute digests.

    Creates an in-memory database, appends all events, builds projections,
    and computes digests.

    Args:
        fixture: Fixture to replay

    Returns:
        Dict mapping digest names to digest values (e.g., "context_graph" -> "sha256:...")
    """
    # Create in-memory store and projector
    store = SQLiteEventStore(":memory:")
    conn = store._conn
    projector = SQLiteProjector(conn)

    # Append all events to store
    for envelope in fixture.events:
        store.append_event(envelope)

    # Rebuild projections from all events
    projector.rebuild()
    all_events = store.list_events()
    projector.project_events(all_events)

    # Compute digests
    return {
        "context_graph": compute_context_graph_digest(conn),
        "trace_summary": compute_trace_summary_digest(conn),
        "precedent_index": compute_precedent_index_digest(conn),
        "full_projection": compute_full_projection_digest(conn),
    }


def validate_fixture(fixture_dir: Path) -> tuple[bool, dict[str, tuple[str, str]]]:
    """Validate fixture digests match expected values.

    Loads fixture, replays it in memory, and compares computed digests
    to expected digests.

    Args:
        fixture_dir: Path to fixture directory

    Returns:
        Tuple of (all_match, mismatches) where:
        - all_match: True if all digests match
        - mismatches: Dict mapping digest names to (expected, actual) tuples
    """
    fixture = load_fixture(fixture_dir)

    # Replay fixture
    actual_digests = replay_fixture(fixture)

    # Compare digests
    mismatches: dict[str, tuple[str, str]] = {}
    for key, expected in fixture.expected_digests.items():
        actual = actual_digests.get(key, "")
        if actual != expected:
            mismatches[key] = (expected, actual)

    all_match = len(mismatches) == 0
    return all_match, mismatches


def validate_no_chain_of_thought(fixture: GoldenFixture) -> list[str]:
    """Validate fixture contains no chain-of-thought content.

    Scans all event payloads for chain-of-thought patterns per SSOT 13.

    Args:
        fixture: Fixture to validate

    Returns:
        List of violations (empty if valid)
    """
    # Chain-of-thought patterns to detect
    cot_patterns = [
        r"\b(thinking|reasoning|let me|i think|i believe)\b",
        r"\b(step \d+:|first|second|third|finally)\b",
        r"\b(conclusion|therefore|thus|hence)\b",
    ]

    violations: list[str] = []

    for i, envelope in enumerate(fixture.events):
        payload_str = json.dumps(envelope.payload, sort_keys=True).lower()

        for pattern in cot_patterns:
            if re.search(pattern, payload_str, re.IGNORECASE):
                violations.append(
                    f"Event {i} ({envelope.event_type}): "
                    f"Contains chain-of-thought pattern '{pattern}'"
                )

    return violations


__all__ = [
    "GoldenFixture",
    "load_fixture",
    "envelope_from_dict",
    "replay_fixture",
    "validate_fixture",
    "validate_no_chain_of_thought",
]
