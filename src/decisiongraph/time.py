"""Time utilities for RFC3339 timestamps."""

from datetime import UTC, datetime


def utc_now() -> datetime:
    """Get current UTC time.

    Returns:
        Current datetime in UTC timezone
    """
    return datetime.now(UTC)


def to_rfc3339(dt: datetime) -> str:
    """Convert datetime to RFC3339 string.

    Args:
        dt: Datetime to convert (should be timezone-aware)

    Returns:
        RFC3339 formatted string (e.g., "2026-01-01T12:00:00.000000Z")
    """
    # Ensure UTC
    dt = dt.replace(tzinfo=UTC) if dt.tzinfo is None else dt.astimezone(UTC)

    # Format with Z suffix for UTC
    return dt.strftime("%Y-%m-%dT%H:%M:%S.%f") + "Z"


def from_rfc3339(s: str) -> datetime:
    """Parse RFC3339 string to datetime.

    Args:
        s: RFC3339 formatted string

    Returns:
        Datetime in UTC timezone

    Raises:
        ValueError: If string is not valid RFC3339
    """
    # Handle Z suffix
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"

    # Parse with timezone
    dt = datetime.fromisoformat(s)

    # Ensure UTC
    dt = dt.replace(tzinfo=UTC) if dt.tzinfo is None else dt.astimezone(UTC)

    return dt


def now_rfc3339() -> str:
    """Get current UTC time as RFC3339 string.

    Returns:
        Current time as RFC3339 string
    """
    return to_rfc3339(utc_now())


__all__ = [
    "utc_now",
    "to_rfc3339",
    "from_rfc3339",
    "now_rfc3339",
]
