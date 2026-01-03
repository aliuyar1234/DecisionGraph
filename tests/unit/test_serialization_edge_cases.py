"""Tests for serialization edge cases.

Covers:
- Deeply nested structures
- Unicode handling
- Empty structures
- Tuple/list normalization
- Float detection at various depths
- Dataclass serialization
- Large payloads
- Hash stability
"""

from dataclasses import dataclass

import pytest

from decisiongraph.errors import DG_ERR_SCHEMA_VIOLATION
from decisiongraph.serialization import compute_payload_hash
from decisiongraph.serialization.canonical_json import (
    FloatFoundError,
    canonicalize_json,
)


class TestDeeplyNestedStructures:
    """Tests for deeply nested JSON structures."""

    def test_deeply_nested_dict(self) -> None:
        """Deeply nested dicts serialize correctly."""
        # Create 50-level deep structure
        data: dict = {"level": 50}
        for i in range(49, 0, -1):
            data = {"level": i, "nested": data}

        result = canonicalize_json(data)
        assert '"level":1' in result
        assert '"level":50' in result

    def test_deeply_nested_list(self) -> None:
        """Deeply nested lists serialize correctly."""
        # Create 50-level deep list structure
        data: list = ["deepest"]
        for _ in range(49):
            data = [data]

        result = canonicalize_json(data)
        assert "deepest" in result

    def test_mixed_deep_nesting(self) -> None:
        """Mixed dicts and lists deeply nested."""
        data: dict | list = {"value": "end"}
        for i in range(25):
            data = [data] if i % 2 == 0 else {"layer": data}

        result = canonicalize_json(data)
        assert "end" in result


class TestUnicodeHandling:
    """Tests for Unicode handling in serialization."""

    def test_emoji_in_values(self) -> None:
        """Emoji characters serialize correctly."""
        data = {"message": "Hello 👋 World 🌍!"}
        result = canonicalize_json(data)
        # ensure_ascii=False means emojis appear as-is
        assert "👋" in result
        assert "🌍" in result

    def test_emoji_in_keys(self) -> None:
        """Emoji characters in keys serialize correctly."""
        data = {"🔑": "key emoji", "📊": "chart emoji"}
        result = canonicalize_json(data)
        assert "🔑" in result

    def test_unicode_combining_characters(self) -> None:
        """Unicode combining characters handled correctly."""
        # é can be represented as e + combining acute accent
        data = {"café": "coffee", "naive\u0308": "with diaeresis"}
        result = canonicalize_json(data)
        assert result  # Should serialize without error

    def test_non_ascii_keys_sorted(self) -> None:
        """Non-ASCII keys sorted correctly."""
        data = {"ü": 3, "a": 1, "ö": 2, "z": 4}
        result = canonicalize_json(data)
        # Keys should be sorted lexicographically
        assert result.index('"a"') < result.index('"z"')

    def test_cjk_characters(self) -> None:
        """CJK characters handled correctly."""
        data = {"中文": "Chinese", "日本語": "Japanese", "한국어": "Korean"}
        result = canonicalize_json(data)
        assert "中文" in result
        assert "日本語" in result
        assert "한국어" in result

    def test_rtl_characters(self) -> None:
        """Right-to-left characters handled correctly."""
        data = {"arabic": "العربية", "hebrew": "עברית"}
        result = canonicalize_json(data)
        assert "العربية" in result
        assert "עברית" in result


class TestEmptyStructures:
    """Tests for empty structure serialization."""

    def test_empty_dict(self) -> None:
        """Empty dict serializes to {}."""
        result = canonicalize_json({})
        assert result == "{}"

    def test_empty_list(self) -> None:
        """Empty list serializes to []."""
        result = canonicalize_json([])
        assert result == "[]"

    def test_nested_empty_structures(self) -> None:
        """Nested empty structures serialize correctly."""
        data = {"empty_dict": {}, "empty_list": [], "nested": {"also_empty": []}}
        result = canonicalize_json(data)
        assert ":{}" in result
        assert ":[]" in result

    def test_empty_string_value(self) -> None:
        """Empty string value serializes correctly."""
        data = {"key": ""}
        result = canonicalize_json(data)
        assert result == '{"key":""}'


class TestTupleListNormalization:
    """Tests for tuple/list normalization."""

    def test_tuple_serializes_as_list(self) -> None:
        """Tuples serialize as JSON arrays."""
        data = {"items": (1, 2, 3)}
        result = canonicalize_json(data)
        assert result == '{"items":[1,2,3]}'

    def test_nested_tuples(self) -> None:
        """Nested tuples serialize correctly."""
        data = {"matrix": ((1, 2), (3, 4))}
        result = canonicalize_json(data)
        assert "[[1,2],[3,4]]" in result

    def test_mixed_tuple_list(self) -> None:
        """Mixed tuples and lists serialize consistently."""
        data1 = {"items": [1, 2, 3]}
        data2 = {"items": (1, 2, 3)}
        result1 = canonicalize_json(data1)
        result2 = canonicalize_json(data2)
        assert result1 == result2


class TestFloatDetection:
    """Tests for float detection at various nesting depths."""

    def test_float_at_top_level_raises(self) -> None:
        """Float at top level raises FloatFoundError."""
        with pytest.raises(FloatFoundError) as exc_info:
            canonicalize_json(3.14)

        assert exc_info.value.code == DG_ERR_SCHEMA_VIOLATION
        assert exc_info.value.float_value == 3.14

    def test_float_in_dict_raises(self) -> None:
        """Float in dict value raises FloatFoundError."""
        data = {"amount": 99.99}
        with pytest.raises(FloatFoundError) as exc_info:
            canonicalize_json(data)

        assert "amount" in exc_info.value.path

    def test_float_in_list_raises(self) -> None:
        """Float in list raises FloatFoundError."""
        data = {"items": [1, 2.5, 3]}
        with pytest.raises(FloatFoundError) as exc_info:
            canonicalize_json(data)

        assert "[1]" in exc_info.value.path

    def test_float_deeply_nested_raises(self) -> None:
        """Float deeply nested raises FloatFoundError."""
        data = {"a": {"b": {"c": {"d": {"value": 0.001}}}}}
        with pytest.raises(FloatFoundError) as exc_info:
            canonicalize_json(data)

        assert "a" in exc_info.value.path
        assert "d" in exc_info.value.path

    def test_zero_float_raises(self) -> None:
        """Zero as float raises FloatFoundError."""
        data = {"zero": 0.0}
        with pytest.raises(FloatFoundError):
            canonicalize_json(data)

    def test_integer_zero_allowed(self) -> None:
        """Integer zero is allowed."""
        data = {"zero": 0}
        result = canonicalize_json(data)
        assert result == '{"zero":0}'

    def test_decimal_as_string_allowed(self) -> None:
        """Decimal represented as string is allowed."""
        data = {"amount": "99.99"}
        result = canonicalize_json(data)
        assert '"99.99"' in result


class TestDataclassSerialization:
    """Tests for dataclass serialization."""

    def test_simple_dataclass(self) -> None:
        """Simple dataclass serializes correctly."""
        @dataclass
        class Person:
            name: str
            age: int

        person = Person(name="Alice", age=30)
        result = canonicalize_json(person)
        assert '"name":"Alice"' in result
        assert '"age":30' in result

    def test_nested_dataclass(self) -> None:
        """Nested dataclasses serialize correctly."""
        @dataclass
        class Address:
            city: str

        @dataclass
        class Person:
            name: str
            address: Address

        person = Person(name="Bob", address=Address(city="NYC"))
        result = canonicalize_json(person)
        assert '"name":"Bob"' in result
        assert '"city":"NYC"' in result

    def test_dataclass_with_list(self) -> None:
        """Dataclass with list field serializes correctly."""
        @dataclass
        class Team:
            name: str
            members: list[str]

        team = Team(name="A-Team", members=["Alice", "Bob", "Charlie"])
        result = canonicalize_json(team)
        assert '"name":"A-Team"' in result
        assert '["Alice","Bob","Charlie"]' in result


class TestLargePayloads:
    """Tests for large payload handling."""

    def test_large_string_value(self) -> None:
        """Large string value serializes correctly."""
        large_string = "x" * 100_000
        data = {"content": large_string}
        result = canonicalize_json(data)
        assert len(result) > 100_000

    def test_many_fields(self) -> None:
        """Dict with many fields serializes correctly."""
        data = {f"field_{i}": i for i in range(1000)}
        result = canonicalize_json(data)
        assert '"field_0":0' in result
        assert '"field_999":999' in result

    def test_long_list(self) -> None:
        """Long list serializes correctly."""
        data = {"numbers": list(range(10000))}
        result = canonicalize_json(data)
        assert "[0," in result
        assert ",9999]" in result


class TestHashStability:
    """Tests for hash stability and consistency."""

    def test_same_data_same_hash(self) -> None:
        """Same data produces same hash."""
        data = {"workflow": "test", "title": "Hash Test", "count": 42}
        hash1 = compute_payload_hash(data)
        hash2 = compute_payload_hash(data)
        assert hash1 == hash2

    def test_key_order_independent(self) -> None:
        """Key order doesn't affect hash."""
        data1 = {"a": 1, "b": 2, "c": 3}
        data2 = {"c": 3, "a": 1, "b": 2}
        data3 = {"b": 2, "c": 3, "a": 1}

        hash1 = compute_payload_hash(data1)
        hash2 = compute_payload_hash(data2)
        hash3 = compute_payload_hash(data3)

        assert hash1 == hash2 == hash3

    def test_different_data_different_hash(self) -> None:
        """Different data produces different hash."""
        hash1 = compute_payload_hash({"value": 1})
        hash2 = compute_payload_hash({"value": 2})
        assert hash1 != hash2

    def test_hash_format(self) -> None:
        """Hash has correct format (sha256: prefix)."""
        hash_value = compute_payload_hash({"test": "data"})
        assert hash_value.startswith("sha256:")
        # SHA-256 produces 64 hex characters
        hex_part = hash_value[7:]
        assert len(hex_part) == 64
        assert all(c in "0123456789abcdef" for c in hex_part)

    def test_nested_key_order_independent(self) -> None:
        """Nested key order doesn't affect hash."""
        data1 = {"outer": {"a": 1, "b": 2}, "value": 42}
        data2 = {"value": 42, "outer": {"b": 2, "a": 1}}

        hash1 = compute_payload_hash(data1)
        hash2 = compute_payload_hash(data2)

        assert hash1 == hash2


class TestCanonicalJsonFormat:
    """Tests for canonical JSON format compliance."""

    def test_no_whitespace(self) -> None:
        """Canonical JSON has no unnecessary whitespace."""
        data = {"key1": "value1", "key2": {"nested": "value"}}
        result = canonicalize_json(data)
        # No spaces after colons or commas
        assert ": " not in result
        assert ", " not in result

    def test_keys_sorted(self) -> None:
        """Keys are sorted lexicographically."""
        data = {"z": 1, "a": 2, "m": 3}
        result = canonicalize_json(data)
        assert result == '{"a":2,"m":3,"z":1}'

    def test_boolean_format(self) -> None:
        """Booleans serialize as lowercase true/false."""
        data = {"yes": True, "no": False}
        result = canonicalize_json(data)
        assert '"yes":true' in result
        assert '"no":false' in result

    def test_null_format(self) -> None:
        """None serializes as null."""
        data = {"empty": None}
        result = canonicalize_json(data)
        assert result == '{"empty":null}'

    def test_string_escaping(self) -> None:
        """Special characters in strings are escaped."""
        data = {"quote": 'He said "hello"', "newline": "line1\nline2"}
        result = canonicalize_json(data)
        assert '\\"' in result  # Escaped quote
        assert "\\n" in result  # Escaped newline


class TestPrimitiveTypes:
    """Tests for primitive type handling."""

    def test_integer_types(self) -> None:
        """Various integer values serialize correctly."""
        data = {
            "zero": 0,
            "positive": 42,
            "negative": -17,
            "large": 10**18,
            "small": -(10**18),
        }
        result = canonicalize_json(data)
        assert ":0" in result
        assert ":42" in result
        assert ":-17" in result

    def test_string_types(self) -> None:
        """Various string values serialize correctly."""
        data = {
            "empty": "",
            "simple": "hello",
            "unicode": "héllo",
            "whitespace": " \t\n ",
        }
        result = canonicalize_json(data)
        assert '""' in result
        assert '"hello"' in result

    def test_boolean_values(self) -> None:
        """Boolean values serialize correctly."""
        data = {"t": True, "f": False}
        result = canonicalize_json(data)
        assert ":true" in result
        assert ":false" in result

    def test_none_value(self) -> None:
        """None value serializes as null."""
        data = {"nothing": None}
        result = canonicalize_json(data)
        assert ":null" in result
