"""Canonical JSON serialization per SSOT 6.1.5.

Canonical JSON rules:
- Keys sorted lexicographically
- No whitespace (separators=(",", ":"))
- No floats at any nesting depth (decimals must be strings)
- UTF-8 encoding
"""

import dataclasses
import json
from typing import Any

from decisiongraph.errors import DG_ERR_SCHEMA_VIOLATION, DecisionGraphError


class FloatFoundError(DecisionGraphError):
    """Raised when a float is found in data to be serialized."""

    def __init__(self, path: str, value: float) -> None:
        super().__init__(
            DG_ERR_SCHEMA_VIOLATION,
            f"Float found at '{path}': {value}. Use string representation for decimals.",
        )
        self.path = path
        self.float_value = value


def _check_no_floats(obj: Any, path: str = "$") -> None:
    """Recursively check for floats at any nesting depth.

    Args:
        obj: Object to check
        path: Current JSON path for error reporting

    Raises:
        FloatFoundError: If a float is found
    """
    if isinstance(obj, float):
        raise FloatFoundError(path, obj)
    elif isinstance(obj, dict):
        for key, value in obj.items():
            _check_no_floats(value, f"{path}.{key}")
    elif isinstance(obj, (list, tuple)):
        for i, item in enumerate(obj):
            _check_no_floats(item, f"{path}[{i}]")
    # int, str, bool, None are allowed


def _to_serializable(obj: Any) -> Any:
    """Convert object to JSON-serializable form.

    Handles dataclasses by converting them to dicts.

    Args:
        obj: Object to convert

    Returns:
        JSON-serializable object
    """
    if dataclasses.is_dataclass(obj) and not isinstance(obj, type):
        return {k: _to_serializable(v) for k, v in dataclasses.asdict(obj).items()}
    elif isinstance(obj, dict):
        return {k: _to_serializable(v) for k, v in obj.items()}
    elif isinstance(obj, (list, tuple)):
        return [_to_serializable(item) for item in obj]
    else:
        return obj


def canonicalize_json(obj: Any) -> str:
    """Convert object to canonical JSON string.

    Canonical JSON rules (SSOT 6.1.5):
    - Keys sorted lexicographically
    - No whitespace
    - No floats (decimals as strings)
    - UTF-8 encoding

    Args:
        obj: Object to serialize (can include dataclasses)

    Returns:
        Canonical JSON string (UTF-8 encoded result as str)

    Raises:
        FloatFoundError: If a float is found at any nesting depth
    """
    # Convert dataclasses to dicts
    serializable = _to_serializable(obj)

    # Check for floats at any nesting depth
    _check_no_floats(serializable)

    # Serialize with sorted keys and no whitespace
    return json.dumps(
        serializable,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    )


def compute_payload_hash(payload: dict[str, Any]) -> str:
    """Compute SHA-256 hash of canonical JSON payload.

    Args:
        payload: Payload dict to hash

    Returns:
        Hash string in format "sha256:<hex>"
    """
    from decisiongraph.serialization.hashing import sha256_prefixed

    canonical = canonicalize_json(payload)
    return sha256_prefixed(canonical.encode("utf-8"))


__all__ = ["canonicalize_json", "compute_payload_hash", "FloatFoundError"]
