"""Shared storage backend utilities.

This module contains common logic shared between SQLite and PostgreSQL backends
to reduce code duplication while keeping database-specific code separate.
"""

import json
from collections.abc import Mapping
from dataclasses import dataclass
from typing import Any

from decisiongraph.domain.events import (
    EVENT_TYPE_TRACE_STARTED,
    EventEnvelope,
    StoredEvent,
)
from decisiongraph.domain.types import ActorRef, SourceRef
from decisiongraph.domain.validation import check_pii_guard, validate_idempotency_key
from decisiongraph.errors import (
    DG_ERR_EVENT_SEQUENCE_INVALID,
    DG_ERR_STORAGE,
    DecisionGraphError,
)
from decisiongraph.serialization import compute_payload_hash
from decisiongraph.time import now_rfc3339


@dataclass(frozen=True)
class PreparedEvent:
    """Event data prepared for database insertion.

    Contains all computed values (hash, json, recorded_at) so that
    database-specific backends don't need to duplicate this logic.
    """

    payload_hash: str
    payload_json: str
    tags_json: str
    recorded_at: str


def prepare_event_for_insert(envelope: EventEnvelope) -> PreparedEvent:
    """Validate and prepare an event envelope for insertion.

    This performs all validation and computation that is common across backends:
    - Idempotency key validation
    - PII guard check
    - Payload hash computation
    - JSON serialization
    - Recorded timestamp

    Args:
        envelope: Event envelope to prepare

    Returns:
        PreparedEvent with computed values

    Raises:
        DecisionGraphError: If validation fails
    """
    # Validate idempotency key
    validate_idempotency_key(envelope.idempotency_key)

    # Check PII guard
    check_pii_guard(envelope.payload)

    # Compute values
    payload_hash = compute_payload_hash(envelope.payload)
    payload_json = json.dumps(envelope.payload, sort_keys=True, ensure_ascii=False)
    tags_json = json.dumps(list(envelope.tags), ensure_ascii=False)
    recorded_at = now_rfc3339()

    return PreparedEvent(
        payload_hash=payload_hash,
        payload_json=payload_json,
        tags_json=tags_json,
        recorded_at=recorded_at,
    )


def validate_trace_seq(
    envelope: EventEnvelope,
    expected_seq: int,
) -> None:
    """Validate trace_seq rules for an event.

    Args:
        envelope: Event envelope to validate
        expected_seq: Expected next trace_seq for this trace

    Raises:
        DecisionGraphError: If trace_seq rules are violated
    """
    # Validate trace_seq matches expected
    if envelope.trace_seq != expected_seq:
        raise DecisionGraphError(
            DG_ERR_EVENT_SEQUENCE_INVALID,
            f"Expected trace_seq {expected_seq}, got {envelope.trace_seq}",
        )

    # TraceStarted must be first event (trace_seq=0)
    if envelope.event_type == EVENT_TYPE_TRACE_STARTED and envelope.trace_seq != 0:
        raise DecisionGraphError(
            DG_ERR_EVENT_SEQUENCE_INVALID,
            "TraceStarted must have trace_seq=0",
        )

    # Non-TraceStarted must not be first event
    if envelope.event_type != EVENT_TYPE_TRACE_STARTED and envelope.trace_seq == 0:
        raise DecisionGraphError(
            DG_ERR_EVENT_SEQUENCE_INVALID,
            f"First event must be TraceStarted, got {envelope.event_type}",
        )


def row_to_stored_event(row: Mapping[str, Any]) -> StoredEvent:
    """Convert a database row to StoredEvent.

    Works with both sqlite3.Row and PostgreSQL dict rows since both
    support dict-like access via row["column_name"].

    Args:
        row: Database row with dict-like access

    Returns:
        StoredEvent instance

    Raises:
        DecisionGraphError: If JSON deserialization fails (corrupted data)
    """
    try:
        payload = json.loads(row["payload_json"])
        tags = json.loads(row["tags_json"])
    except json.JSONDecodeError as e:
        raise DecisionGraphError(
            DG_ERR_STORAGE,
            f"Failed to deserialize event data for event_id={row.get('event_id', 'unknown')}: {e}",
        ) from e

    return StoredEvent(
        log_seq=row["log_seq"],
        event_id=row["event_id"],
        trace_id=row["trace_id"],
        trace_seq=row["trace_seq"],
        event_type=row["event_type"],
        occurred_at=row["occurred_at"],
        recorded_at=row["recorded_at"],
        source=SourceRef(
            producer_id=row["producer_id"],
            system=row["system"],
            subsystem=row["subsystem"],
        ),
        actor=ActorRef(
            actor_type=row["actor_type"],
            actor_id=row["actor_id"],
        ),
        idempotency_key=row["idempotency_key"],
        payload=payload,
        payload_hash=row["payload_hash"],
        correlation_id=row["correlation_id"],
        causation_event_id=row["causation_event_id"],
        schema_version=row["schema_version"],
        tags=tags,
    )


__all__ = [
    "PreparedEvent",
    "prepare_event_for_insert",
    "validate_trace_seq",
    "row_to_stored_event",
]
