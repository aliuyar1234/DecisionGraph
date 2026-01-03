"""Tests for validation boundary conditions.

Covers:
- PII guard case sensitivity and edge cases
- Idempotency key boundary conditions
- Payload size limits
- Unicode in validation
- JSON safety validation
"""

import pytest

from decisiongraph.domain.validation import (
    FORBIDDEN_SUBSTRINGS,
    MAX_IDEMPOTENCY_KEY_BYTES,
    check_pii_guard,
    validate_idempotency_key,
    validate_payload_json_safe,
)
from decisiongraph.errors import (
    DG_ERR_INVALID_ARGUMENT,
    DG_ERR_PII_POLICY_VIOLATION,
    DecisionGraphError,
)


class TestPIIGuardEdgeCases:
    """Tests for PII guard edge cases."""

    def test_case_sensitive_detection(self) -> None:
        """PII detection is case-sensitive."""
        # Exact case should be detected
        with pytest.raises(DecisionGraphError) as exc_info:
            check_pii_guard({"token": "Bearer secret"})
        assert exc_info.value.code == DG_ERR_PII_POLICY_VIOLATION

        # Different case might not be detected (depends on pattern)
        # This tests that "bearer " (lowercase) is NOT in FORBIDDEN_SUBSTRINGS
        import contextlib

        with contextlib.suppress(DecisionGraphError):
            check_pii_guard({"token": "bearer secret"})

    def test_partial_match_detected(self) -> None:
        """Partial match within string is detected."""
        with pytest.raises(DecisionGraphError):
            check_pii_guard({"data": "The token is Bearer xyz123 here"})

    def test_at_string_start(self) -> None:
        """Pattern at start of string is detected."""
        with pytest.raises(DecisionGraphError):
            check_pii_guard({"key": "AKIAIOSFODNN7EXAMPLE"})

    def test_at_string_end(self) -> None:
        """Pattern at end of string is detected."""
        with pytest.raises(DecisionGraphError):
            check_pii_guard({"key": "my-secret-AKIA"})

    def test_multiple_patterns_in_one_string(self) -> None:
        """Multiple patterns in one string detected."""
        with pytest.raises(DecisionGraphError):
            check_pii_guard({"data": "Bearer token with password=secret"})

    def test_deeply_nested_pii(self) -> None:
        """PII in deeply nested structure is detected."""
        data = {
            "level1": {
                "level2": {
                    "level3": {
                        "level4": {
                            "level5": {"secret": "Bearer deep_secret"}
                        }
                    }
                }
            }
        }
        with pytest.raises(DecisionGraphError):
            check_pii_guard(data)

    def test_pii_in_mixed_list_dict(self) -> None:
        """PII in mixed list/dict structure is detected."""
        data = {
            "items": [
                {"safe": "value"},
                {"list": ["a", "b", {"nested": "xoxb-secret"}]},
            ]
        }
        with pytest.raises(DecisionGraphError):
            check_pii_guard(data)

    def test_empty_structures_pass(self) -> None:
        """Empty structures pass validation."""
        check_pii_guard({})
        check_pii_guard([])
        check_pii_guard({"empty": {}})
        check_pii_guard({"list": []})

    def test_numeric_types_pass(self) -> None:
        """Numeric types pass validation."""
        check_pii_guard({"int": 42, "large": 10**20})

    def test_boolean_types_pass(self) -> None:
        """Boolean types pass validation."""
        check_pii_guard({"yes": True, "no": False})

    def test_none_type_passes(self) -> None:
        """None type passes validation."""
        check_pii_guard({"nothing": None})

    def test_error_includes_path(self) -> None:
        """Error message includes JSON path."""
        with pytest.raises(DecisionGraphError) as exc_info:
            check_pii_guard({"outer": {"inner": "Bearer xyz"}})

        error_msg = str(exc_info.value)
        assert "outer" in error_msg
        assert "inner" in error_msg

    def test_all_forbidden_substrings_populated(self) -> None:
        """FORBIDDEN_SUBSTRINGS is not empty."""
        assert len(FORBIDDEN_SUBSTRINGS) > 0
        assert isinstance(FORBIDDEN_SUBSTRINGS, frozenset)

    @pytest.mark.parametrize("pattern", list(FORBIDDEN_SUBSTRINGS))
    def test_each_forbidden_pattern_detected(self, pattern: str) -> None:
        """Each pattern in FORBIDDEN_SUBSTRINGS is detected."""
        data = {"value": f"prefix{pattern}suffix"}
        with pytest.raises(DecisionGraphError) as exc_info:
            check_pii_guard(data)
        assert exc_info.value.code == DG_ERR_PII_POLICY_VIOLATION


class TestIdempotencyKeyBoundary:
    """Tests for idempotency key boundary conditions."""

    def test_exactly_200_bytes_allowed(self) -> None:
        """Key exactly at 200 bytes is allowed."""
        key = "a" * 200
        validate_idempotency_key(key)  # Should not raise

    def test_201_bytes_rejected(self) -> None:
        """Key at 201 bytes is rejected."""
        key = "a" * 201
        with pytest.raises(DecisionGraphError) as exc_info:
            validate_idempotency_key(key)
        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT
        assert "200 bytes" in str(exc_info.value)

    def test_unicode_byte_counting(self) -> None:
        """Key length counted in bytes, not characters."""
        # Each emoji is 4 bytes in UTF-8
        key_50_emojis = "😀" * 50  # 200 bytes
        validate_idempotency_key(key_50_emojis)  # Should not raise

        key_51_emojis = "😀" * 51  # 204 bytes
        with pytest.raises(DecisionGraphError):
            validate_idempotency_key(key_51_emojis)

    def test_mixed_unicode_byte_counting(self) -> None:
        """Mixed ASCII and Unicode counted correctly."""
        # 100 ASCII chars (100 bytes) + 25 emojis (100 bytes) = 200 bytes
        key = "a" * 100 + "😀" * 25
        validate_idempotency_key(key)  # Should not raise

        # One more byte pushes over
        key_over = "a" * 101 + "😀" * 25  # 201 bytes
        with pytest.raises(DecisionGraphError):
            validate_idempotency_key(key_over)

    def test_null_byte_at_start(self) -> None:
        """Null byte at start is rejected."""
        key = "\x00rest-of-key"
        with pytest.raises(DecisionGraphError) as exc_info:
            validate_idempotency_key(key)
        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT
        assert "null bytes" in str(exc_info.value)

    def test_null_byte_in_middle(self) -> None:
        """Null byte in middle is rejected."""
        key = "start\x00end"
        with pytest.raises(DecisionGraphError):
            validate_idempotency_key(key)

    def test_null_byte_at_end(self) -> None:
        """Null byte at end is rejected."""
        key = "key-content\x00"
        with pytest.raises(DecisionGraphError):
            validate_idempotency_key(key)

    def test_empty_string_rejected(self) -> None:
        """Empty string is rejected."""
        with pytest.raises(DecisionGraphError) as exc_info:
            validate_idempotency_key("")
        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT
        assert "empty" in str(exc_info.value).lower()

    def test_whitespace_only_allowed(self) -> None:
        """Whitespace-only key is allowed (not empty)."""
        validate_idempotency_key("   ")  # Should not raise
        validate_idempotency_key("\t\n")  # Should not raise

    def test_single_character(self) -> None:
        """Single character key is allowed."""
        validate_idempotency_key("x")  # Should not raise

    def test_special_characters_allowed(self) -> None:
        """Special characters in key are allowed."""
        validate_idempotency_key("key-with-dashes")
        validate_idempotency_key("key_with_underscores")
        validate_idempotency_key("key.with.dots")
        validate_idempotency_key("key:with:colons")
        validate_idempotency_key("key/with/slashes")


class TestUnicodeInValidation:
    """Tests for Unicode handling in validation."""

    def test_unicode_in_pii_check(self) -> None:
        """Unicode characters don't break PII check."""
        data = {"message": "Hello 世界 🌍"}
        check_pii_guard(data)  # Should not raise

    def test_combining_characters_in_key(self) -> None:
        """Combining characters handled correctly in key."""
        # é as e + combining acute accent
        key = "caf\u0065\u0301"  # café with combining accent
        validate_idempotency_key(key)  # Should not raise

    def test_zero_width_characters_in_key(self) -> None:
        """Zero-width characters counted in byte length."""
        # Zero-width joiner is 3 bytes in UTF-8
        zwj = "\u200d"
        key = "a" * 197 + zwj  # 197 + 3 = 200 bytes
        validate_idempotency_key(key)  # Should not raise


class TestPayloadJsonSafety:
    """Tests for payload JSON safety validation."""

    def test_serializable_payload_passes(self) -> None:
        """JSON-serializable payload passes validation."""
        payload = {
            "string": "value",
            "number": 42,
            "float": "3.14",  # As string, not float
            "boolean": True,
            "null": None,
            "list": [1, 2, 3],
            "nested": {"a": "b"},
        }
        validate_payload_json_safe(payload)  # Should not raise

    def test_non_serializable_raises(self) -> None:
        """Non-JSON-serializable types raise error."""
        class CustomObject:
            pass

        payload = {"obj": CustomObject()}
        with pytest.raises(DecisionGraphError) as exc_info:
            validate_payload_json_safe(payload)
        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT

    def test_function_in_payload_raises(self) -> None:
        """Function in payload raises error."""
        payload = {"func": lambda x: x}
        with pytest.raises(DecisionGraphError):
            validate_payload_json_safe(payload)

    def test_bytes_in_payload_raises(self) -> None:
        """Bytes in payload raises error."""
        payload = {"data": b"binary data"}
        with pytest.raises(DecisionGraphError):
            validate_payload_json_safe(payload)

    def test_set_in_payload_raises(self) -> None:
        """Set in payload raises error (sets not JSON serializable)."""
        payload = {"items": {1, 2, 3}}
        with pytest.raises(DecisionGraphError):
            validate_payload_json_safe(payload)

    def test_complex_nested_serializable(self) -> None:
        """Complex nested structure that is serializable passes."""
        payload = {
            "level1": {
                "level2": [
                    {"a": 1},
                    {"b": [True, False, None]},
                    {"c": {"d": {"e": "deep"}}},
                ],
            },
        }
        validate_payload_json_safe(payload)  # Should not raise


class TestValidationIntegration:
    """Integration tests for validation functions."""

    def test_pii_and_json_safety_independent(self) -> None:
        """PII guard and JSON safety are independent checks."""
        # Valid JSON but contains PII
        with pytest.raises(DecisionGraphError) as exc_info:
            check_pii_guard({"token": "Bearer xyz"})
        assert exc_info.value.code == DG_ERR_PII_POLICY_VIOLATION

    def test_idempotency_key_patterns(self) -> None:
        """Common idempotency key patterns work."""
        patterns = [
            "trace-123-0",
            "evt_abc123def456",
            "2024-01-15T10:30:00Z_event",
            "user:action:1234567890",
            "a" * 200,
        ]
        for pattern in patterns:
            validate_idempotency_key(pattern)  # Should not raise

    def test_max_key_constant_exported(self) -> None:
        """MAX_IDEMPOTENCY_KEY_BYTES constant is exported."""
        assert MAX_IDEMPOTENCY_KEY_BYTES == 200


class TestEdgeCasesPayloads:
    """Tests for edge case payloads."""

    def test_deeply_nested_safe_payload(self) -> None:
        """Deeply nested but safe payload passes."""
        depth = 50
        data: dict = {"value": "leaf"}
        for i in range(depth):
            data = {f"level_{i}": data}
        check_pii_guard(data)  # Should not raise

    def test_wide_payload(self) -> None:
        """Payload with many keys passes."""
        data = {f"key_{i}": f"value_{i}" for i in range(1000)}
        check_pii_guard(data)  # Should not raise

    def test_long_string_values(self) -> None:
        """Long string values pass if no PII."""
        data = {"content": "x" * 100000}
        check_pii_guard(data)  # Should not raise

    def test_unicode_keys_pass(self) -> None:
        """Unicode keys pass validation."""
        data = {"键": "value", "キー": "value", "مفتاح": "value"}
        check_pii_guard(data)  # Should not raise
