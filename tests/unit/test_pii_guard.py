"""Tests for PII guard - TC-P1-011."""

import pytest

from decisiongraph.domain.events import EVENT_TYPE_TRACE_STARTED
from decisiongraph.domain.validation import (
    FORBIDDEN_SUBSTRINGS,
    check_pii_guard,
    validate_idempotency_key,
)
from decisiongraph.errors import (
    DG_ERR_INVALID_ARGUMENT,
    DG_ERR_PII_POLICY_VIOLATION,
    DecisionGraphError,
)
from decisiongraph.ids import generate_trace_id
from decisiongraph.testing import InMemoryEventStore, create_test_envelope


class TestPIIGuard:
    """Tests for PII guard function."""

    def test_pii_guard_rejects_bearer(self) -> None:
        """TC-P1-011: PII guard rejects Bearer token."""
        data = {"token": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"}

        with pytest.raises(DecisionGraphError) as exc_info:
            check_pii_guard(data)

        assert exc_info.value.code == DG_ERR_PII_POLICY_VIOLATION
        assert "Bearer " in str(exc_info.value)

    def test_pii_guard_rejects_slack_token(self) -> None:
        """Rejects Slack bot token."""
        data = {"slack_token": "xoxb-123456789-abcdefghijk"}

        with pytest.raises(DecisionGraphError) as exc_info:
            check_pii_guard(data)

        assert exc_info.value.code == DG_ERR_PII_POLICY_VIOLATION

    def test_pii_guard_rejects_private_key(self) -> None:
        """Rejects private key content."""
        data = {"key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBg"}

        with pytest.raises(DecisionGraphError) as exc_info:
            check_pii_guard(data)

        assert exc_info.value.code == DG_ERR_PII_POLICY_VIOLATION

    def test_pii_guard_rejects_aws_key(self) -> None:
        """Rejects AWS access key."""
        data = {"aws_key": "AKIAIOSFODNN7EXAMPLE"}

        with pytest.raises(DecisionGraphError) as exc_info:
            check_pii_guard(data)

        assert exc_info.value.code == DG_ERR_PII_POLICY_VIOLATION

    def test_pii_guard_rejects_password(self) -> None:
        """Rejects password in query string format."""
        data = {"url": "https://example.com?password=secret123"}

        with pytest.raises(DecisionGraphError) as exc_info:
            check_pii_guard(data)

        assert exc_info.value.code == DG_ERR_PII_POLICY_VIOLATION

    def test_pii_guard_rejects_nested(self) -> None:
        """Rejects forbidden content in nested structures."""
        data = {
            "outer": {
                "inner": {
                    "token": "Bearer secret123",
                },
            },
        }

        with pytest.raises(DecisionGraphError) as exc_info:
            check_pii_guard(data)

        assert exc_info.value.code == DG_ERR_PII_POLICY_VIOLATION

    def test_pii_guard_rejects_in_list(self) -> None:
        """Rejects forbidden content in lists."""
        data = {"items": ["safe", "xoxb-token-here", "also safe"]}

        with pytest.raises(DecisionGraphError) as exc_info:
            check_pii_guard(data)

        assert exc_info.value.code == DG_ERR_PII_POLICY_VIOLATION

    def test_pii_guard_allows_safe_content(self) -> None:
        """Allows safe content."""
        data = {
            "workflow": "renewal",
            "title": "Process customer request",
            "amount": "1000.00",
            "status": "pending",
        }

        # Should not raise
        check_pii_guard(data)

    def test_pii_guard_allows_integers(self) -> None:
        """Integers are not checked (no string content)."""
        data = {"count": 42, "items": [1, 2, 3]}
        check_pii_guard(data)

    def test_pii_guard_allows_booleans(self) -> None:
        """Booleans are not checked."""
        data = {"active": True, "verified": False}
        check_pii_guard(data)

    def test_pii_guard_allows_null(self) -> None:
        """Null values are not checked."""
        data = {"optional": None}
        check_pii_guard(data)

    @pytest.mark.parametrize(
        "forbidden",
        [
            "Bearer ",
            "xoxb-",
            "xoxp-",
            "-----BEGIN",
            "AKIA",
            "ghp_",
            "password=",
            "api_key=",
        ],
    )
    def test_each_forbidden_substring(self, forbidden: str) -> None:
        """Each forbidden substring is rejected."""
        data = {"value": f"contains {forbidden}secret data"}

        with pytest.raises(DecisionGraphError) as exc_info:
            check_pii_guard(data)

        assert exc_info.value.code == DG_ERR_PII_POLICY_VIOLATION

    def test_forbidden_substrings_not_empty(self) -> None:
        """FORBIDDEN_SUBSTRINGS is populated."""
        assert len(FORBIDDEN_SUBSTRINGS) > 0


class TestPIIGuardInStore:
    """Tests for PII guard integration with InMemoryEventStore."""

    def test_store_rejects_pii_payload(self) -> None:
        """Store rejects event with PII in payload."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        env = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={
                "workflow": "test",
                "title": "Test",
                "token": "Bearer secret123",  # PII!
            },
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            store.append_event(env)

        assert exc_info.value.code == DG_ERR_PII_POLICY_VIOLATION


class TestIdempotencyKeyValidation:
    """Tests for idempotency key validation."""

    def test_empty_key_rejected(self) -> None:
        """Empty idempotency key is rejected."""
        with pytest.raises(DecisionGraphError) as exc_info:
            validate_idempotency_key("")

        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT

    def test_valid_key_accepted(self) -> None:
        """Valid idempotency key is accepted."""
        validate_idempotency_key("trace-123-0")  # Should not raise

    def test_long_key_rejected(self) -> None:
        """Key exceeding 200 bytes is rejected."""
        # Create a key longer than 200 bytes
        long_key = "a" * 201

        with pytest.raises(DecisionGraphError) as exc_info:
            validate_idempotency_key(long_key)

        assert exc_info.value.code == DG_ERR_INVALID_ARGUMENT
        assert "200 bytes" in str(exc_info.value)

    def test_unicode_key_byte_length(self) -> None:
        """Unicode characters count by byte length, not character count."""
        # Each emoji is 4 bytes in UTF-8
        # 50 emojis = 200 bytes (at limit)
        at_limit = "\U0001F600" * 50  # 50 emojis = 200 bytes
        validate_idempotency_key(at_limit)  # Should not raise

        # 51 emojis = 204 bytes (over limit)
        over_limit = "\U0001F600" * 51
        with pytest.raises(DecisionGraphError):
            validate_idempotency_key(over_limit)
