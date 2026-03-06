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

REFERENCE_FIXTURE_BUNDLE_FORMAT = "decisiongraph.reference_fixture_bundle"
REFERENCE_FIXTURE_BUNDLE_VERSION = 1


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


def discover_fixture_dirs(fixtures_root: Path) -> list[Path]:
    """Discover fixture directories in deterministic order."""
    return sorted(
        [
            path
            for path in fixtures_root.iterdir()
            if path.is_dir()
            and (path / "events.json").exists()
            and (path / "expected_digest.txt").exists()
        ],
        key=lambda path: path.name,
    )


def load_all_fixtures(fixtures_root: Path) -> list[GoldenFixture]:
    """Load every golden fixture under a root directory."""
    return [load_fixture(path) for path in discover_fixture_dirs(fixtures_root)]


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


def event_envelope_to_dict(envelope: EventEnvelope) -> dict[str, Any]:
    """Convert EventEnvelope to a deterministic JSON-compatible dict."""
    return {
        "actor": {
            "actor_id": envelope.actor.actor_id,
            "actor_type": envelope.actor.actor_type,
        },
        "causation_event_id": envelope.causation_event_id,
        "correlation_id": envelope.correlation_id,
        "event_id": envelope.event_id,
        "event_type": envelope.event_type,
        "idempotency_key": envelope.idempotency_key,
        "occurred_at": envelope.occurred_at,
        "payload": envelope.payload,
        "schema_version": envelope.schema_version,
        "source": {
            "producer_id": envelope.source.producer_id,
            "subsystem": envelope.source.subsystem,
            "system": envelope.source.system,
        },
        "tags": list(envelope.tags),
        "trace_id": envelope.trace_id,
        "trace_seq": envelope.trace_seq,
    }


def _normalize_projection_snapshot(fixture: GoldenFixture) -> dict[str, Any]:
    with SQLiteEventStore(":memory:") as store:
        projector = SQLiteProjector(store.connection)

        for envelope in fixture.events:
            store.append_event(envelope)

        projector.rebuild()
        projector.project_events(store.list_events())

        nodes = [
            {
                "attrs": json.loads(row["metadata_json"]),
                "created_at": row["created_at"],
                "log_seq": row["log_seq"],
                "node_id": row["node_id"],
                "node_type": row["node_type"],
                "trace_id": row["trace_id"],
            }
            for row in projector.get_nodes()
        ]
        edges = [
            {
                "attrs": json.loads(row["metadata_json"]),
                "created_at": row["created_at"],
                "edge_id": row["edge_id"],
                "edge_type": row["edge_type"],
                "from_node_id": row["from_node_id"],
                "log_seq": row["log_seq"],
                "to_node_id": row["to_node_id"],
                "trace_id": row["trace_id"],
            }
            for row in projector.get_edges()
        ]

        trace_summary_row = projector.get_trace_summary(fixture.trace_id)
        trace_summary = None
        if trace_summary_row is not None:
            trace_summary = {
                "event_count": trace_summary_row["event_count"],
                "finished_at": trace_summary_row["finished_at"],
                "last_log_seq": trace_summary_row["last_log_seq"],
                "outcome": trace_summary_row["outcome"],
                "primary_entity_id": trace_summary_row["primary_entity_id"],
                "primary_entity_type": trace_summary_row["primary_entity_type"],
                "started_at": trace_summary_row["started_at"],
                "title": trace_summary_row["title"],
                "trace_id": trace_summary_row["trace_id"],
                "workflow": trace_summary_row["workflow"],
            }

        precedent_rows = projector.execute_query(
            """
            SELECT source_event_id, log_seq, trace_id, policy_id, policy_version,
                   exception_id, primary_entity_type, primary_entity_system, primary_entity_id
            FROM dg_precedent_index
            ORDER BY source_event_id
            """
        )
        precedent_index = [
            {
                "exception_id": row["exception_id"],
                "log_seq": row["log_seq"],
                "policy_id": row["policy_id"],
                "policy_version": row["policy_version"],
                "primary_entity_id": row["primary_entity_id"],
                "primary_entity_system": row["primary_entity_system"],
                "primary_entity_type": row["primary_entity_type"],
                "source_event_id": row["source_event_id"],
                "trace_id": row["trace_id"],
            }
            for row in precedent_rows
        ]

        policy_rows = projector.execute_query(
            """
            SELECT index_id, trace_id, policy_id, policy_version, log_seq, created_at
            FROM dg_policy_eval_index
            ORDER BY log_seq ASC, index_id ASC
            """
        )
        policy_eval_index = [
            {
                "created_at": row["created_at"],
                "index_id": row["index_id"],
                "log_seq": row["log_seq"],
                "policy_id": row["policy_id"],
                "policy_version": row["policy_version"],
                "trace_id": row["trace_id"],
            }
            for row in policy_rows
        ]

        return {
            "context_graph": {
                "edge_count": len(edges),
                "edges": edges,
                "node_count": len(nodes),
                "nodes": nodes,
            },
            "policy_eval_index": policy_eval_index,
            "precedent_index": precedent_index,
            "projection_cursor": projector.get_cursor(),
            "trace_summary": trace_summary,
        }


def fixture_to_dict(
    fixture: GoldenFixture,
    *,
    include_projection_snapshot: bool = True,
) -> dict[str, Any]:
    """Convert a fixture into the exported parity-bundle format."""
    data: dict[str, Any] = {
        "description": fixture.description,
        "event_count": len(fixture.events),
        "event_type_sequence": [event.event_type for event in fixture.events],
        "events": [event_envelope_to_dict(event) for event in fixture.events],
        "expected_digests": dict(sorted(fixture.expected_digests.items())),
        "scenario": fixture.scenario,
        "ssot_reference": fixture.ssot_reference,
        "trace_id": fixture.trace_id,
    }
    if include_projection_snapshot:
        data["projection_snapshot"] = _normalize_projection_snapshot(fixture)
    return data


def build_fixture_bundle(
    fixtures: list[GoldenFixture],
    *,
    include_projection_snapshots: bool = True,
) -> dict[str, Any]:
    """Build a deterministic cross-language parity bundle from fixtures."""
    ordered_fixtures = sorted(fixtures, key=lambda fixture: fixture.scenario)
    return {
        "format": REFERENCE_FIXTURE_BUNDLE_FORMAT,
        "scenario_count": len(ordered_fixtures),
        "scenarios": [
            fixture_to_dict(
                fixture,
                include_projection_snapshot=include_projection_snapshots,
            )
            for fixture in ordered_fixtures
        ],
        "version": REFERENCE_FIXTURE_BUNDLE_VERSION,
    }


def export_fixture_bundle(
    fixtures: list[GoldenFixture],
    output_path: Path,
    *,
    include_projection_snapshots: bool = True,
) -> Path:
    """Export a deterministic fixture bundle for cross-language parity tests."""
    bundle = build_fixture_bundle(
        fixtures,
        include_projection_snapshots=include_projection_snapshots,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(bundle, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return output_path


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
    conn = store.connection
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
    "REFERENCE_FIXTURE_BUNDLE_FORMAT",
    "REFERENCE_FIXTURE_BUNDLE_VERSION",
    "build_fixture_bundle",
    "discover_fixture_dirs",
    "event_envelope_to_dict",
    "export_fixture_bundle",
    "fixture_to_dict",
    "load_all_fixtures",
    "load_fixture",
    "envelope_from_dict",
    "replay_fixture",
    "validate_fixture",
    "validate_no_chain_of_thought",
]
