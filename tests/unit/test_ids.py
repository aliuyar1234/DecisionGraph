"""Unit tests for ID generation utilities."""

import uuid

from decisiongraph.ids import (
    generate_event_id,
    generate_id,
    generate_trace_id,
    is_valid_uuid,
)


class TestGenerateId:
    """Tests for generate_id function."""

    def test_returns_string(self) -> None:
        result = generate_id()
        assert isinstance(result, str)

    def test_returns_valid_uuid(self) -> None:
        result = generate_id()
        # Should not raise
        uuid.UUID(result)

    def test_returns_lowercase(self) -> None:
        result = generate_id()
        assert result == result.lower()

    def test_returns_unique_values(self) -> None:
        ids = [generate_id() for _ in range(100)]
        assert len(set(ids)) == 100


class TestGenerateEventId:
    """Tests for generate_event_id function."""

    def test_returns_valid_uuid(self) -> None:
        result = generate_event_id()
        uuid.UUID(result)

    def test_returns_unique_values(self) -> None:
        ids = [generate_event_id() for _ in range(100)]
        assert len(set(ids)) == 100


class TestGenerateTraceId:
    """Tests for generate_trace_id function."""

    def test_returns_valid_uuid(self) -> None:
        result = generate_trace_id()
        uuid.UUID(result)

    def test_returns_unique_values(self) -> None:
        ids = [generate_trace_id() for _ in range(100)]
        assert len(set(ids)) == 100


class TestIsValidUuid:
    """Tests for is_valid_uuid function."""

    def test_valid_uuid(self) -> None:
        assert is_valid_uuid("550e8400-e29b-41d4-a716-446655440000")

    def test_valid_uuid_uppercase(self) -> None:
        assert is_valid_uuid("550E8400-E29B-41D4-A716-446655440000")

    def test_invalid_uuid(self) -> None:
        assert not is_valid_uuid("not-a-uuid")

    def test_empty_string(self) -> None:
        assert not is_valid_uuid("")

    def test_partial_uuid(self) -> None:
        assert not is_valid_uuid("550e8400-e29b-41d4")
