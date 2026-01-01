"""ID generation utilities per SSOT DD-007."""

import uuid


def generate_id() -> str:
    """Generate a new UUID4 string.

    Returns:
        A lowercase UUID4 string (e.g., "550e8400-e29b-41d4-a716-446655440000")
    """
    return str(uuid.uuid4())


def generate_event_id() -> str:
    """Generate a new event ID.

    Returns:
        A lowercase UUID4 string for use as event_id
    """
    return generate_id()


def generate_trace_id() -> str:
    """Generate a new trace ID.

    Returns:
        A lowercase UUID4 string for use as trace_id
    """
    return generate_id()


def is_valid_uuid(value: str) -> bool:
    """Check if a string is a valid UUID.

    Args:
        value: String to validate

    Returns:
        True if valid UUID, False otherwise
    """
    try:
        uuid.UUID(value)
        return True
    except (ValueError, AttributeError):
        return False


__all__ = [
    "generate_id",
    "generate_event_id",
    "generate_trace_id",
    "is_valid_uuid",
]
