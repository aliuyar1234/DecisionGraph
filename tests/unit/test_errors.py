"""Tests for error handling module."""

import pytest

from decisiongraph.errors import (
    DG_ERR_CONFLICT,
    DG_ERR_EVENT_SEQUENCE_INVALID,
    DG_ERR_IDEMPOTENCY_CONFLICT,
    DG_ERR_INVALID_ARGUMENT,
    DG_ERR_NOT_FOUND,
    DG_ERR_PII_POLICY_VIOLATION,
    DG_ERR_PROJECTION_OUT_OF_DATE,
    DG_ERR_SCHEMA_VIOLATION,
    DG_ERR_STORAGE,
    ERROR_CODES,
    DecisionGraphError,
)


class TestDecisionGraphError:
    """Tests for DecisionGraphError class."""

    def test_init(self) -> None:
        """Error initializes with code and message."""
        error = DecisionGraphError(DG_ERR_NOT_FOUND, "Resource not found")
        assert error.code == DG_ERR_NOT_FOUND
        assert error.message == "Resource not found"

    def test_str_format(self) -> None:
        """Error string format is '{code}: {message}'."""
        error = DecisionGraphError(DG_ERR_CONFLICT, "Conflict occurred")
        assert str(error) == "DG_ERR_CONFLICT: Conflict occurred"

    def test_repr(self) -> None:
        """Error has useful repr."""
        error = DecisionGraphError(DG_ERR_STORAGE, "Database error")
        assert "DecisionGraphError" in repr(error)
        assert "DG_ERR_STORAGE" in repr(error)

    def test_is_exception(self) -> None:
        """Error is an Exception subclass."""
        error = DecisionGraphError(DG_ERR_NOT_FOUND, "Not found")
        assert isinstance(error, Exception)

    def test_can_be_raised(self) -> None:
        """Error can be raised and caught."""
        with pytest.raises(DecisionGraphError) as exc_info:
            raise DecisionGraphError(DG_ERR_INVALID_ARGUMENT, "Bad input")

        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT
        assert exc_info.value.message == "Bad input"


class TestErrorCodes:
    """Tests for error code constants."""

    def test_all_codes_in_set(self) -> None:
        """All individual codes are in ERROR_CODES set."""
        assert DG_ERR_NOT_FOUND in ERROR_CODES
        assert DG_ERR_CONFLICT in ERROR_CODES
        assert DG_ERR_IDEMPOTENCY_CONFLICT in ERROR_CODES
        assert DG_ERR_SCHEMA_VIOLATION in ERROR_CODES
        assert DG_ERR_EVENT_SEQUENCE_INVALID in ERROR_CODES
        assert DG_ERR_PROJECTION_OUT_OF_DATE in ERROR_CODES
        assert DG_ERR_INVALID_ARGUMENT in ERROR_CODES
        assert DG_ERR_STORAGE in ERROR_CODES
        assert DG_ERR_PII_POLICY_VIOLATION in ERROR_CODES

    def test_code_count(self) -> None:
        """Exactly 9 error codes per SSOT 7.2."""
        assert len(ERROR_CODES) == 9

    def test_codes_are_strings(self) -> None:
        """All codes are strings."""
        for code in ERROR_CODES:
            assert isinstance(code, str)

    def test_codes_start_with_prefix(self) -> None:
        """All codes start with DG_ERR_."""
        for code in ERROR_CODES:
            assert code.startswith("DG_ERR_")

    def test_error_codes_immutable(self) -> None:
        """ERROR_CODES is a frozenset (immutable)."""
        assert isinstance(ERROR_CODES, frozenset)
