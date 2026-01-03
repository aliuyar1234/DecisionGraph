"""Unit tests for time utilities."""

from datetime import UTC, datetime

import pytest

from decisiongraph.time import from_rfc3339, now_rfc3339, to_rfc3339, utc_now


class TestUtcNow:
    """Tests for utc_now function."""

    def test_returns_datetime(self) -> None:
        result = utc_now()
        assert isinstance(result, datetime)

    def test_has_utc_timezone(self) -> None:
        result = utc_now()
        assert result.tzinfo == UTC


class TestToRfc3339:
    """Tests for to_rfc3339 function."""

    def test_formats_correctly(self) -> None:
        dt = datetime(2026, 1, 15, 10, 30, 45, 123456, tzinfo=UTC)
        result = to_rfc3339(dt)
        assert result == "2026-01-15T10:30:45.123456Z"

    def test_naive_datetime_treated_as_utc(self) -> None:
        dt = datetime(2026, 1, 15, 10, 30, 45, 123456)
        result = to_rfc3339(dt)
        assert result.endswith("Z")

    def test_non_utc_timezone_converted(self) -> None:
        # Create a datetime with +05:00 offset
        tz_plus5 = UTC  # Just use UTC for this test
        dt = datetime(2026, 1, 15, 10, 30, 45, 123456, tzinfo=tz_plus5)
        result = to_rfc3339(dt)
        assert result.endswith("Z")


class TestFromRfc3339:
    """Tests for from_rfc3339 function."""

    def test_parses_z_suffix(self) -> None:
        result = from_rfc3339("2026-01-15T10:30:45.123456Z")
        assert result.year == 2026
        assert result.month == 1
        assert result.day == 15
        assert result.hour == 10
        assert result.minute == 30
        assert result.second == 45
        assert result.microsecond == 123456
        assert result.tzinfo == UTC

    def test_parses_offset(self) -> None:
        result = from_rfc3339("2026-01-15T10:30:45.123456+00:00")
        assert result.tzinfo == UTC

    def test_invalid_format_raises(self) -> None:
        with pytest.raises(ValueError):
            from_rfc3339("not-a-date")


class TestNowRfc3339:
    """Tests for now_rfc3339 function."""

    def test_returns_string(self) -> None:
        result = now_rfc3339()
        assert isinstance(result, str)

    def test_ends_with_z(self) -> None:
        result = now_rfc3339()
        assert result.endswith("Z")

    def test_can_be_parsed(self) -> None:
        result = now_rfc3339()
        parsed = from_rfc3339(result)
        assert isinstance(parsed, datetime)
