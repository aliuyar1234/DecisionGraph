"""Tests for canonical JSON serialization - TC-P1-001 through TC-P1-004."""

import pytest

from decisiongraph.serialization import (
    FloatFoundError,
    canonicalize_json,
    compute_payload_hash,
)


class TestCanonicalJson:
    """Tests for canonicalize_json function."""

    def test_key_order(self) -> None:
        """TC-P1-001: Keys are sorted lexicographically."""
        # Keys in non-sorted order
        obj = {"zebra": 1, "alpha": 2, "beta": 3}
        result = canonicalize_json(obj)

        # Should be sorted: alpha, beta, zebra
        assert result == '{"alpha":2,"beta":3,"zebra":1}'

    def test_nested_key_order(self) -> None:
        """Nested objects also have sorted keys."""
        obj = {"z": {"c": 1, "a": 2, "b": 3}, "a": {"y": 1, "x": 2}}
        result = canonicalize_json(obj)

        # Both outer and inner keys should be sorted
        assert result == '{"a":{"x":2,"y":1},"z":{"a":2,"b":3,"c":1}}'

    def test_no_whitespace(self) -> None:
        """TC-P1-002: No whitespace in output."""
        obj = {"key": "value", "list": [1, 2, 3], "nested": {"a": 1}}
        result = canonicalize_json(obj)

        # No spaces or newlines
        assert " " not in result
        assert "\n" not in result
        assert "\t" not in result

    def test_reject_float_top_level(self) -> None:
        """TC-P1-004: Float at top level is rejected."""
        with pytest.raises(FloatFoundError) as exc_info:
            canonicalize_json({"value": 3.14})

        assert exc_info.value.code == "DG_ERR_SCHEMA_VIOLATION"
        assert "$.value" in str(exc_info.value)

    def test_reject_float_nested(self) -> None:
        """Float in nested structure is rejected."""
        with pytest.raises(FloatFoundError):
            canonicalize_json({"outer": {"inner": 2.71}})

    def test_reject_float_in_list(self) -> None:
        """Float in list is rejected."""
        with pytest.raises(FloatFoundError) as exc_info:
            canonicalize_json({"items": [1, 2, 3.0, 4]})

        assert "$[2]" in exc_info.value.path or "items" in exc_info.value.path

    def test_reject_float_deeply_nested(self) -> None:
        """Float deeply nested is rejected."""
        obj = {"a": {"b": {"c": {"d": [{"e": 1.5}]}}}}
        with pytest.raises(FloatFoundError):
            canonicalize_json(obj)

    def test_allow_int(self) -> None:
        """Integers are allowed."""
        result = canonicalize_json({"value": 42})
        assert result == '{"value":42}'

    def test_allow_string(self) -> None:
        """Strings are allowed."""
        result = canonicalize_json({"value": "hello"})
        assert result == '{"value":"hello"}'

    def test_allow_bool(self) -> None:
        """Booleans are allowed."""
        result = canonicalize_json({"yes": True, "no": False})
        assert result == '{"no":false,"yes":true}'

    def test_allow_null(self) -> None:
        """Null values are allowed."""
        result = canonicalize_json({"value": None})
        assert result == '{"value":null}'

    def test_allow_list(self) -> None:
        """Lists are allowed."""
        result = canonicalize_json({"items": [1, 2, 3]})
        assert result == '{"items":[1,2,3]}'

    def test_decimal_as_string(self) -> None:
        """Decimals should be strings, not floats."""
        result = canonicalize_json({"price": "123.45"})
        assert result == '{"price":"123.45"}'

    def test_deterministic_output(self) -> None:
        """Same input produces identical output every time."""
        obj = {"b": 2, "a": 1, "c": {"z": 26, "y": 25}}

        results = [canonicalize_json(obj) for _ in range(100)]

        # All results should be identical
        assert len(set(results)) == 1

    def test_unicode_preserved(self) -> None:
        """Unicode characters are preserved (not escaped)."""
        result = canonicalize_json({"greeting": "Hello, 世界!"})
        assert "世界" in result


class TestComputePayloadHash:
    """Tests for compute_payload_hash function."""

    def test_hash_matches(self) -> None:
        """TC-P1-003: payload_hash matches recomputed hash."""
        payload = {"workflow": "renewal", "title": "Test trace"}

        hash1 = compute_payload_hash(payload)
        hash2 = compute_payload_hash(payload)

        assert hash1 == hash2
        assert hash1.startswith("sha256:")

    def test_different_payloads_different_hash(self) -> None:
        """Different payloads produce different hashes."""
        hash1 = compute_payload_hash({"a": 1})
        hash2 = compute_payload_hash({"a": 2})

        assert hash1 != hash2

    def test_key_order_doesnt_affect_hash(self) -> None:
        """Key order doesn't affect hash (canonical sorting)."""
        hash1 = compute_payload_hash({"b": 2, "a": 1})
        hash2 = compute_payload_hash({"a": 1, "b": 2})

        assert hash1 == hash2

    def test_hash_format(self) -> None:
        """Hash has correct format."""
        result = compute_payload_hash({"test": "data"})

        assert result.startswith("sha256:")
        # SHA-256 produces 64 hex characters
        hex_part = result.split(":")[1]
        assert len(hex_part) == 64
        assert all(c in "0123456789abcdef" for c in hex_part)
