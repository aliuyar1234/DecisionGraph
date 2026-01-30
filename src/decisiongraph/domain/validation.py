"""Domain validation utilities per SSOT 6.1.8.

This module provides:
- PII guard (forbidden substring detection)
- Idempotency key validation
- Payload structure validation
"""

from __future__ import annotations

import json
from typing import Any

from decisiongraph.domain.events import (
    ALL_EVENT_TYPES,
    EVENT_TYPE_ACTION_COMMITTED,
    EVENT_TYPE_ACTION_PROPOSED,
    EVENT_TYPE_APPROVAL_RECORDED,
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_EXCEPTION_REQUESTED,
    EVENT_TYPE_INPUT_OBSERVED,
    EVENT_TYPE_POLICY_EVALUATED,
    EVENT_TYPE_PRECEDENT_CITED,
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
    EventEnvelope,
)
from decisiongraph.errors import (
    DG_ERR_INVALID_ARGUMENT,
    DG_ERR_PII_POLICY_VIOLATION,
    DG_ERR_SCHEMA_VIOLATION,
    DecisionGraphError,
)

# Forbidden substrings per SSOT 6.1.8.1
# These patterns indicate secrets or PII that should not be stored
FORBIDDEN_SUBSTRINGS: frozenset[str] = frozenset({
    # API tokens
    "Bearer ",
    "xoxb-",  # Slack bot token
    "xoxp-",  # Slack user token
    "xoxa-",  # Slack app token
    "xoxr-",  # Slack refresh token
    "sk-",    # OpenAI API key prefix (common)
    "ghp_",   # GitHub personal access token
    "gho_",   # GitHub OAuth token
    "ghu_",   # GitHub user-to-server token
    "ghs_",   # GitHub server-to-server token
    "ghr_",   # GitHub refresh token
    # Private keys
    "-----BEGIN",
    "-----BEGIN PRIVATE KEY",
    "-----BEGIN RSA PRIVATE KEY",
    "-----BEGIN EC PRIVATE KEY",
    "-----BEGIN OPENSSH PRIVATE KEY",
    # AWS
    "AKIA",   # AWS access key ID prefix
    "ASIA",   # AWS temporary access key ID prefix
    # Other common patterns
    "api_key=",
    "apikey=",
    "api-key:",
    "password=",
    "passwd=",
    "secret=",
    "token=",
})

FORBIDDEN_SUBSTRINGS_LOWER: tuple[tuple[str, str], ...] = tuple(
    (pattern, pattern.lower()) for pattern in sorted(FORBIDDEN_SUBSTRINGS)
)

# Maximum idempotency key length in bytes
MAX_IDEMPOTENCY_KEY_BYTES = 200


def check_pii_guard(data: Any, path: str = "$") -> None:
    """Check for forbidden PII/secret patterns in data.

    Recursively scans all string values in the data structure.

    Args:
        data: Data to check (can be dict, list, or scalar)
        path: Current JSON path for error reporting

    Raises:
        DecisionGraphError: With DG_ERR_PII_POLICY_VIOLATION if forbidden content found
    """
    if isinstance(data, str):
        lowered = data.lower()
        for original, lowered_pattern in FORBIDDEN_SUBSTRINGS_LOWER:
            if lowered_pattern in lowered:
                raise DecisionGraphError(
                    DG_ERR_PII_POLICY_VIOLATION,
                    f"Forbidden content '{original}' found at '{path}'",
                )
    elif isinstance(data, dict):
        for key, value in data.items():
            check_pii_guard(value, f"{path}.{key}")
    elif isinstance(data, (list, tuple)):
        for i, item in enumerate(data):
            check_pii_guard(item, f"{path}[{i}]")
    # int, float, bool, None are allowed (no string content to check)


def check_event_pii(envelope: EventEnvelope) -> None:
    """Check PII guard across payload and event metadata.

    Args:
        envelope: Event envelope to validate

    Raises:
        DecisionGraphError: With DG_ERR_PII_POLICY_VIOLATION if forbidden content found
    """
    metadata = {
        "payload": envelope.payload,
        "tags": list(envelope.tags),
        "actor": {
            "actor_type": envelope.actor.actor_type,
            "actor_id": envelope.actor.actor_id,
        },
        "source": {
            "producer_id": envelope.source.producer_id,
            "system": envelope.source.system,
            "subsystem": envelope.source.subsystem,
        },
        "correlation_id": envelope.correlation_id,
        "causation_event_id": envelope.causation_event_id,
        "idempotency_key": envelope.idempotency_key,
    }
    check_pii_guard(metadata)


def validate_idempotency_key(key: str) -> None:
    """Validate idempotency key constraints.

    Args:
        key: Idempotency key to validate

    Raises:
        DecisionGraphError: With DG_ERR_INVALID_ARGUMENT if:
            - Key is empty
            - Key contains null bytes
            - Key exceeds 200 bytes when UTF-8 encoded
    """
    if not key:
        raise DecisionGraphError(
            DG_ERR_INVALID_ARGUMENT,
            "Idempotency key cannot be empty",
        )

    # Null bytes can cause truncation in C-based libraries and SQL
    if "\x00" in key:
        raise DecisionGraphError(
            DG_ERR_INVALID_ARGUMENT,
            "Idempotency key cannot contain null bytes",
        )

    key_bytes = key.encode("utf-8")
    if len(key_bytes) > MAX_IDEMPOTENCY_KEY_BYTES:
        raise DecisionGraphError(
            DG_ERR_INVALID_ARGUMENT,
            f"Idempotency key exceeds {MAX_IDEMPOTENCY_KEY_BYTES} bytes "
            f"(got {len(key_bytes)} bytes)",
        )


def validate_payload_json_safe(payload: dict[str, Any]) -> None:
    """Validate that payload can be safely serialized to JSON.

    Args:
        payload: Payload dict to validate

    Raises:
        DecisionGraphError: With DG_ERR_INVALID_ARGUMENT if payload is not JSON-serializable
    """
    try:
        json.dumps(payload)
    except (TypeError, ValueError) as e:
        raise DecisionGraphError(
            DG_ERR_INVALID_ARGUMENT,
            f"Payload is not JSON-serializable: {e}",
        ) from e


def _require_dict(payload: dict[str, Any], key: str, path: str) -> dict[str, Any]:
    value = payload.get(key)
    if not isinstance(value, dict):
        raise DecisionGraphError(
            DG_ERR_SCHEMA_VIOLATION,
            f"Missing or invalid object for '{path}.{key}'",
        )
    return value


def _require_str(payload: dict[str, Any], key: str, path: str) -> str:
    value = payload.get(key)
    if not isinstance(value, str) or not value:
        raise DecisionGraphError(
            DG_ERR_SCHEMA_VIOLATION,
            f"Missing or invalid string for '{path}.{key}'",
        )
    return value


def _require_list(payload: dict[str, Any], key: str, path: str) -> list[Any]:
    value = payload.get(key)
    if not isinstance(value, list):
        raise DecisionGraphError(
            DG_ERR_SCHEMA_VIOLATION,
            f"Missing or invalid list for '{path}.{key}'",
        )
    return value


def validate_payload_schema(event_type: str, payload: dict[str, Any]) -> None:
    """Validate payload structure based on event type.

    Args:
        event_type: Event type string
        payload: Payload dict to validate

    Raises:
        DecisionGraphError: With DG_ERR_SCHEMA_VIOLATION if payload is invalid
    """
    if event_type not in ALL_EVENT_TYPES:
        raise DecisionGraphError(
            DG_ERR_SCHEMA_VIOLATION,
            f"Unknown event_type '{event_type}'",
        )

    if not isinstance(payload, dict):
        raise DecisionGraphError(
            DG_ERR_SCHEMA_VIOLATION,
            "Payload must be a dict",
        )

    if event_type == EVENT_TYPE_TRACE_STARTED:
        _require_str(payload, "workflow", "$")
        _require_str(payload, "title", "$")
        primary_entity = _require_dict(payload, "primary_entity", "$")
        _require_str(primary_entity, "entity_type", "$.primary_entity")
        _require_str(primary_entity, "entity_id", "$.primary_entity")
    elif event_type == EVENT_TYPE_INPUT_OBSERVED:
        _require_str(payload, "input_id", "$")
        source = _require_dict(payload, "source", "$")
        _require_str(source, "system", "$.source")
        _require_str(source, "object_type", "$.source")
        _require_str(source, "object_id", "$.source")
        _require_list(payload, "facts", "$")
    elif event_type == EVENT_TYPE_ENTITY_OBSERVED:
        entity = _require_dict(payload, "entity", "$")
        _require_str(entity, "entity_type", "$.entity")
        _require_str(entity, "entity_id", "$.entity")
        _require_str(payload, "role", "$")
        _require_list(payload, "facts", "$")
    elif event_type == EVENT_TYPE_POLICY_EVALUATED:
        policy = _require_dict(payload, "policy", "$")
        _require_str(policy, "policy_id", "$.policy")
        _require_str(policy, "policy_version", "$.policy")
        _require_list(payload, "inputs", "$")
        _require_str(payload, "decision", "$")
    elif event_type == EVENT_TYPE_EXCEPTION_REQUESTED:
        _require_str(payload, "exception_id", "$")
        policy = _require_dict(payload, "policy", "$")
        _require_str(policy, "policy_id", "$.policy")
        _require_str(policy, "policy_version", "$.policy")
        _require_str(payload, "reason", "$")
    elif event_type == EVENT_TYPE_APPROVAL_RECORDED:
        _require_str(payload, "approval_id", "$")
        subject = _require_dict(payload, "subject", "$")
        _require_str(subject, "subject_type", "$.subject")
        _require_str(subject, "subject_id", "$.subject")
        approver = _require_dict(payload, "approver", "$")
        _require_str(approver, "actor_type", "$.approver")
        _require_str(approver, "actor_id", "$.approver")
        _require_str(payload, "decision", "$")
    elif event_type == EVENT_TYPE_PRECEDENT_CITED:
        _require_str(payload, "cited_trace_id", "$")
        _require_str(payload, "reason", "$")
    elif event_type == EVENT_TYPE_ACTION_PROPOSED:
        _require_str(payload, "action_id", "$")
        _require_str(payload, "action_type", "$")
        target_entity = _require_dict(payload, "target_entity", "$")
        _require_str(target_entity, "entity_type", "$.target_entity")
        _require_str(target_entity, "entity_id", "$.target_entity")
        _require_str(payload, "target_system", "$")
        _require_list(payload, "changes", "$")
    elif event_type == EVENT_TYPE_ACTION_COMMITTED:
        _require_str(payload, "action_id", "$")
        _require_str(payload, "status", "$")
    elif event_type == EVENT_TYPE_TRACE_FINISHED:
        _require_str(payload, "outcome", "$")


__all__ = [
    "FORBIDDEN_SUBSTRINGS",
    "MAX_IDEMPOTENCY_KEY_BYTES",
    "check_pii_guard",
    "check_event_pii",
    "validate_idempotency_key",
    "validate_payload_schema",
    "validate_payload_json_safe",
]
