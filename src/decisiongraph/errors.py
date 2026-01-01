"""DecisionGraph error types and codes per SSOT 7.2/11.1."""

from typing import Final

# Error codes per SSOT 7.2
DG_ERR_NOT_FOUND: Final[str] = "DG_ERR_NOT_FOUND"
DG_ERR_CONFLICT: Final[str] = "DG_ERR_CONFLICT"
DG_ERR_IDEMPOTENCY_CONFLICT: Final[str] = "DG_ERR_IDEMPOTENCY_CONFLICT"
DG_ERR_SCHEMA_VIOLATION: Final[str] = "DG_ERR_SCHEMA_VIOLATION"
DG_ERR_EVENT_SEQUENCE_INVALID: Final[str] = "DG_ERR_EVENT_SEQUENCE_INVALID"
DG_ERR_PROJECTION_OUT_OF_DATE: Final[str] = "DG_ERR_PROJECTION_OUT_OF_DATE"
DG_ERR_INVALID_ARGUMENT: Final[str] = "DG_ERR_INVALID_ARGUMENT"
DG_ERR_STORAGE: Final[str] = "DG_ERR_STORAGE"
DG_ERR_PII_POLICY_VIOLATION: Final[str] = "DG_ERR_PII_POLICY_VIOLATION"

# All valid error codes
ERROR_CODES: Final[frozenset[str]] = frozenset({
    DG_ERR_NOT_FOUND,
    DG_ERR_CONFLICT,
    DG_ERR_IDEMPOTENCY_CONFLICT,
    DG_ERR_SCHEMA_VIOLATION,
    DG_ERR_EVENT_SEQUENCE_INVALID,
    DG_ERR_PROJECTION_OUT_OF_DATE,
    DG_ERR_INVALID_ARGUMENT,
    DG_ERR_STORAGE,
    DG_ERR_PII_POLICY_VIOLATION,
})


class DecisionGraphError(Exception):
    """Base exception for all DecisionGraph errors.

    Attributes:
        code: Error code from SSOT 7.2 (e.g., DG_ERR_NOT_FOUND)
        message: Human-readable error message
    """

    def __init__(self, code: str, message: str) -> None:
        """Initialize with error code and message.

        Args:
            code: Error code from SSOT 7.2
            message: Human-readable error message
        """
        self.code = code
        self.message = message
        super().__init__(f"{code}: {message}")

    def __str__(self) -> str:
        """Return formatted error string."""
        return f"{self.code}: {self.message}"

    def __repr__(self) -> str:
        """Return repr string."""
        return f"DecisionGraphError({self.code!r}, {self.message!r})"


__all__ = [
    "DecisionGraphError",
    "ERROR_CODES",
    "DG_ERR_NOT_FOUND",
    "DG_ERR_CONFLICT",
    "DG_ERR_IDEMPOTENCY_CONFLICT",
    "DG_ERR_SCHEMA_VIOLATION",
    "DG_ERR_EVENT_SEQUENCE_INVALID",
    "DG_ERR_PROJECTION_OUT_OF_DATE",
    "DG_ERR_INVALID_ARGUMENT",
    "DG_ERR_STORAGE",
    "DG_ERR_PII_POLICY_VIOLATION",
]
