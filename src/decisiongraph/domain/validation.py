"""Domain validation utilities per SSOT 6.1.8.

This module provides:
- PII guard (forbidden substring detection)
- Idempotency key validation
- Payload structure validation
"""

import json
from typing import Any

from decisiongraph.errors import (
    DG_ERR_INVALID_ARGUMENT,
    DG_ERR_PII_POLICY_VIOLATION,
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
        for forbidden in FORBIDDEN_SUBSTRINGS:
            if forbidden in data:
                raise DecisionGraphError(
                    DG_ERR_PII_POLICY_VIOLATION,
                    f"Forbidden content '{forbidden}' found at '{path}'",
                )
    elif isinstance(data, dict):
        for key, value in data.items():
            check_pii_guard(value, f"{path}.{key}")
    elif isinstance(data, (list, tuple)):
        for i, item in enumerate(data):
            check_pii_guard(item, f"{path}[{i}]")
    # int, float, bool, None are allowed (no string content to check)


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


__all__ = [
    "FORBIDDEN_SUBSTRINGS",
    "MAX_IDEMPOTENCY_KEY_BYTES",
    "check_pii_guard",
    "validate_idempotency_key",
    "validate_payload_json_safe",
]
