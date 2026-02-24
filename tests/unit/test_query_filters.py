"""Unit tests for query filter types per SSOT 8.1 (TC-P5-*)."""

import pytest

from decisiongraph.errors import DG_ERR_INVALID_ARGUMENT, DecisionGraphError
from decisiongraph.query.filters import EventFilter, GraphEdgeCursor, GraphFilter


class TestEventFilter:
    """Test EventFilter validation and behavior."""

    def test_valid_filter(self) -> None:
        """Test creating a valid EventFilter."""
        f = EventFilter(
            trace_id="trace-123",
            event_type="TraceStarted",
            since_log_seq=10,
            until_log_seq=100,
            limit=50,
        )
        assert f.trace_id == "trace-123"
        assert f.limit == 50

    def test_since_greater_than_until_raises(self) -> None:
        """Test that since_log_seq > until_log_seq raises ValueError."""
        with pytest.raises(
            DecisionGraphError, match="since_log_seq must be <= until_log_seq"
        ) as exc_info:
            EventFilter(since_log_seq=100, until_log_seq=10)
        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT

    def test_negative_since_raises(self) -> None:
        """Test that negative since_log_seq raises ValueError."""
        with pytest.raises(
            DecisionGraphError, match="since_log_seq must be non-negative"
        ) as exc_info:
            EventFilter(since_log_seq=-1)
        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT

    def test_limit_too_large_raises(self) -> None:
        """Test that limit > 10000 raises ValueError."""
        with pytest.raises(
            DecisionGraphError, match="limit must be <= 10000"
        ) as exc_info:
            EventFilter(limit=10001)
        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT

    def test_zero_limit_raises(self) -> None:
        """Test that limit = 0 raises ValueError."""
        with pytest.raises(
            DecisionGraphError, match="limit must be positive"
        ) as exc_info:
            EventFilter(limit=0)
        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT


class TestGraphFilter:
    """Test GraphFilter validation and behavior."""

    def test_defaults(self) -> None:
        """Test GraphFilter default values."""
        f = GraphFilter()
        assert f.max_depth == 1
        assert f.max_nodes == 100
        assert f.max_edges == 500

    def test_max_depth_too_large_raises(self) -> None:
        """Test that max_depth > 10 raises ValueError."""
        with pytest.raises(
            DecisionGraphError, match="max_depth must be <= 10"
        ) as exc_info:
            GraphFilter(max_depth=11)
        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT

    def test_negative_max_depth_raises(self) -> None:
        """Test that negative max_depth raises ValueError."""
        with pytest.raises(
            DecisionGraphError, match="max_depth must be non-negative"
        ) as exc_info:
            GraphFilter(max_depth=-1)
        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT

    def test_empty_edge_types_raises(self) -> None:
        """Test that empty edge_types list raises ValueError."""
        with pytest.raises(
            DecisionGraphError, match="edge_types must not be empty"
        ) as exc_info:
            GraphFilter(edge_types=[])
        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT


class TestGraphEdgeCursor:
    """Test GraphEdgeCursor behavior."""

    def test_valid_cursor(self) -> None:
        """Test creating a valid GraphEdgeCursor."""
        cursor = GraphEdgeCursor(edge_key="edge-123", direction="outgoing")
        assert cursor.edge_key == "edge-123"
        assert cursor.direction == "outgoing"
        assert cursor.log_seq is None

    def test_valid_cursor_with_log_seq(self) -> None:
        """Cursor can include log_seq for stable ordering."""
        cursor = GraphEdgeCursor(
            edge_key="edge-123",
            direction="outgoing",
            log_seq=42,
        )
        assert cursor.log_seq == 42

    def test_empty_edge_key_raises(self) -> None:
        """Test that empty edge_key raises ValueError."""
        with pytest.raises(
            DecisionGraphError, match="edge_key must not be empty"
        ) as exc_info:
            GraphEdgeCursor(edge_key="", direction="both")
        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT

    def test_invalid_direction_raises(self) -> None:
        """Test that invalid direction raises ValueError."""
        with pytest.raises(
            DecisionGraphError,
            match='direction must be "outgoing", "incoming", or "both"',
        ) as exc_info:
            GraphEdgeCursor(edge_key="edge-123", direction="invalid")  # type: ignore
        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT

    def test_non_positive_log_seq_raises(self) -> None:
        """Test that non-positive log_seq raises ValueError."""
        with pytest.raises(
            DecisionGraphError, match="log_seq must be positive when provided"
        ) as exc_info:
            GraphEdgeCursor(edge_key="edge-123", direction="both", log_seq=0)
        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT
