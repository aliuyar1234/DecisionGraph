"""Tests for domain types module."""

from dataclasses import FrozenInstanceError

import pytest

from decisiongraph.domain import (
    ActorRef,
    ApprovalSubject,
    Change,
    EntityRef,
    EvidenceRef,
    Fact,
    PolicyRef,
    SourceObjectRef,
    SourceRef,
    Value,
    Violation,
)


class TestActorRef:
    """Tests for ActorRef dataclass."""

    def test_create_agent(self) -> None:
        """Create agent actor."""
        actor = ActorRef(actor_type="agent", actor_id="renewal-agent")
        assert actor.actor_type == "agent"
        assert actor.actor_id == "renewal-agent"

    def test_create_person(self) -> None:
        """Create person actor."""
        actor = ActorRef(actor_type="person", actor_id="user-123")
        assert actor.actor_type == "person"

    def test_create_role(self) -> None:
        """Create role actor."""
        actor = ActorRef(actor_type="role", actor_id="finance-approver")
        assert actor.actor_type == "role"

    def test_create_system(self) -> None:
        """Create system actor."""
        actor = ActorRef(actor_type="system", actor_id="crm-sync")
        assert actor.actor_type == "system"

    def test_frozen(self) -> None:
        """ActorRef is immutable."""
        actor = ActorRef(actor_type="agent", actor_id="test")
        with pytest.raises(FrozenInstanceError):
            actor.actor_id = "changed"  # type: ignore[misc]


class TestEntityRef:
    """Tests for EntityRef dataclass."""

    def test_create_basic(self) -> None:
        """Create entity without system."""
        entity = EntityRef(entity_type="Account", entity_id="acc-123")
        assert entity.entity_type == "Account"
        assert entity.entity_id == "acc-123"
        assert entity.system is None

    def test_create_with_system(self) -> None:
        """Create entity with system."""
        entity = EntityRef(
            entity_type="Account", entity_id="acc-123", system="salesforce"
        )
        assert entity.system == "salesforce"

    def test_frozen(self) -> None:
        """EntityRef is immutable."""
        entity = EntityRef(entity_type="Account", entity_id="acc-123")
        with pytest.raises(FrozenInstanceError):
            entity.entity_id = "changed"  # type: ignore[misc]


class TestValue:
    """Tests for Value dataclass."""

    def test_string_value(self) -> None:
        """Create string value."""
        value = Value(type="string", value="hello")
        assert value.type == "string"
        assert value.value == "hello"

    def test_int_value(self) -> None:
        """Create int value (stored as string)."""
        value = Value(type="int", value="42")
        assert value.type == "int"
        assert value.value == "42"

    def test_bool_value(self) -> None:
        """Create bool value (stored as string)."""
        value = Value(type="bool", value="true")
        assert value.type == "bool"
        assert value.value == "true"

    def test_decimal_value(self) -> None:
        """Create decimal value (stored as string, not float)."""
        value = Value(type="decimal", value="123.45")
        assert value.type == "decimal"
        assert value.value == "123.45"
        # Verify it's a string, not a float
        assert isinstance(value.value, str)

    def test_date_value(self) -> None:
        """Create date value."""
        value = Value(type="date", value="2026-01-01")
        assert value.type == "date"

    def test_datetime_value(self) -> None:
        """Create datetime value."""
        value = Value(type="datetime", value="2026-01-01T12:00:00Z")
        assert value.type == "datetime"

    def test_json_value(self) -> None:
        """Create JSON value."""
        value = Value(type="json", value='{"key": "value"}')
        assert value.type == "json"


class TestFact:
    """Tests for Fact dataclass."""

    def test_create_basic(self) -> None:
        """Create fact without as_of."""
        value = Value(type="decimal", value="1000000")
        fact = Fact(key="annual_revenue", value=value)
        assert fact.key == "annual_revenue"
        assert fact.value == value
        assert fact.as_of is None

    def test_create_with_as_of(self) -> None:
        """Create fact with as_of timestamp."""
        value = Value(type="string", value="Enterprise")
        fact = Fact(key="tier", value=value, as_of="2026-01-01T00:00:00Z")
        assert fact.as_of == "2026-01-01T00:00:00Z"


class TestSourceRef:
    """Tests for SourceRef dataclass."""

    def test_create_basic(self) -> None:
        """Create source without subsystem."""
        source = SourceRef(producer_id="renewal-agent-1", system="crm")
        assert source.producer_id == "renewal-agent-1"
        assert source.system == "crm"
        assert source.subsystem is None

    def test_create_with_subsystem(self) -> None:
        """Create source with subsystem."""
        source = SourceRef(
            producer_id="renewal-agent-1", system="crm", subsystem="accounts"
        )
        assert source.subsystem == "accounts"


class TestSourceObjectRef:
    """Tests for SourceObjectRef dataclass."""

    def test_create_basic(self) -> None:
        """Create source object without locator."""
        obj = SourceObjectRef(system="crm", object_type="Account", object_id="acc-123")
        assert obj.system == "crm"
        assert obj.object_type == "Account"
        assert obj.object_id == "acc-123"
        assert obj.locator is None

    def test_create_with_locator(self) -> None:
        """Create source object with locator."""
        obj = SourceObjectRef(
            system="crm",
            object_type="Account",
            object_id="acc-123",
            locator="https://crm.example.com/accounts/acc-123",
        )
        assert obj.locator is not None


class TestEvidenceRef:
    """Tests for EvidenceRef dataclass."""

    def test_create_basic(self) -> None:
        """Create evidence without excerpt."""
        source = SourceObjectRef(
            system="docs", object_type="Policy", object_id="pol-1"
        )
        evidence = EvidenceRef(source=source, locator="/policies/discount.md#section-3")
        assert evidence.source == source
        assert evidence.locator == "/policies/discount.md#section-3"
        assert evidence.excerpt_redacted is None

    def test_create_with_excerpt(self) -> None:
        """Create evidence with redacted excerpt."""
        source = SourceObjectRef(
            system="docs", object_type="Policy", object_id="pol-1"
        )
        evidence = EvidenceRef(
            source=source,
            locator="/policies/discount.md",
            excerpt_redacted="Maximum discount is [REDACTED]%",
        )
        assert evidence.excerpt_redacted is not None


class TestPolicyRef:
    """Tests for PolicyRef dataclass."""

    def test_create(self) -> None:
        """Create policy reference."""
        policy = PolicyRef(policy_id="discount-policy", policy_version="2.1")
        assert policy.policy_id == "discount-policy"
        assert policy.policy_version == "2.1"


class TestViolation:
    """Tests for Violation dataclass."""

    def test_create_basic(self) -> None:
        """Create violation without details."""
        violation = Violation(
            code="MAX_DISCOUNT_EXCEEDED",
            message="Discount exceeds maximum allowed",
        )
        assert violation.code == "MAX_DISCOUNT_EXCEEDED"
        assert violation.message == "Discount exceeds maximum allowed"
        assert violation.details is None

    def test_create_with_details(self) -> None:
        """Create violation with details."""
        violation = Violation(
            code="MAX_DISCOUNT_EXCEEDED",
            message="Discount exceeds maximum allowed",
            details={"requested": "25%", "maximum": "20%"},
        )
        assert violation.details == {"requested": "25%", "maximum": "20%"}


class TestChange:
    """Tests for Change dataclass."""

    def test_create_with_old_value(self) -> None:
        """Create change with old and new value."""
        old = Value(type="decimal", value="100.00")
        new = Value(type="decimal", value="120.00")
        change = Change(path="amount", old_value=old, new_value=new)
        assert change.path == "amount"
        assert change.old_value == old
        assert change.new_value == new

    def test_create_without_old_value(self) -> None:
        """Create change for new field (no old value)."""
        new = Value(type="string", value="premium")
        change = Change(path="tier", old_value=None, new_value=new)
        assert change.old_value is None
        assert change.new_value == new


class TestApprovalSubject:
    """Tests for ApprovalSubject dataclass."""

    def test_create_exception(self) -> None:
        """Create exception approval subject."""
        subject = ApprovalSubject(subject_type="exception", subject_id="exc-123")
        assert subject.subject_type == "exception"
        assert subject.subject_id == "exc-123"

    def test_create_action(self) -> None:
        """Create action approval subject."""
        subject = ApprovalSubject(subject_type="action", subject_id="act-456")
        assert subject.subject_type == "action"
        assert subject.subject_id == "act-456"
