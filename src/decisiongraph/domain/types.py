"""Domain types per SSOT 11.2.

All types are stdlib dataclasses with frozen=True per DD-004.
"""

from dataclasses import dataclass
from typing import Literal


@dataclass(frozen=True)
class ActorRef:
    """Reference to an actor (agent, person, role, system).

    Attributes:
        actor_type: Type of actor - must be one of the literal values
        actor_id: Unique identifier for the actor
    """

    actor_type: Literal["agent", "person", "role", "system"]
    actor_id: str


@dataclass(frozen=True)
class EntityRef:
    """Reference to a business entity (Account, Ticket, etc.).

    Attributes:
        entity_type: Type of entity (e.g., "Account", "Ticket")
        entity_id: Unique identifier for the entity
        system: Optional source system identifier
    """

    entity_type: str
    entity_id: str
    system: str | None = None


@dataclass(frozen=True)
class Value:
    """Typed value with string representation.

    All values are stored as strings per DD-008 (no floats).
    Decimals are stored as "123.45", not float.

    Attributes:
        type: Data type of the value
        value: String representation of the value
    """

    type: Literal["string", "int", "bool", "decimal", "date", "datetime", "json"]
    value: str


@dataclass(frozen=True)
class Fact:
    """Key-value pair with optional as_of timestamp.

    Attributes:
        key: Fact key/name
        value: Typed value
        as_of: Optional RFC3339 timestamp for temporal facts
    """

    key: str
    value: Value
    as_of: str | None = None


@dataclass(frozen=True)
class SourceRef:
    """Reference to source system (producer identification).

    Attributes:
        producer_id: Unique identifier for the producer
        system: Source system name
        subsystem: Optional subsystem within the source system
    """

    producer_id: str
    system: str
    subsystem: str | None = None


@dataclass(frozen=True)
class SourceObjectRef:
    """Reference to source system object.

    Attributes:
        system: Source system name
        object_type: Type of object in source system
        object_id: Unique identifier for the object
        locator: Optional URI or path to the object
    """

    system: str
    object_type: str
    object_id: str
    locator: str | None = None


@dataclass(frozen=True)
class EvidenceRef:
    """Reference to evidence with optional redacted excerpt.

    Attributes:
        source: Reference to the source object
        locator: URI or path to the evidence
        excerpt_redacted: Optional redacted excerpt of evidence
    """

    source: SourceObjectRef
    locator: str
    excerpt_redacted: str | None = None


@dataclass(frozen=True)
class PolicyRef:
    """Reference to a policy.

    Attributes:
        policy_id: Unique identifier for the policy
        policy_version: Version of the policy
    """

    policy_id: str
    policy_version: str


@dataclass(frozen=True)
class Violation:
    """Policy violation with code and details.

    Attributes:
        code: Violation code
        message: Human-readable violation message
        details: Optional additional details as key-value pairs
    """

    code: str
    message: str
    details: dict[str, str] | None = None


@dataclass(frozen=True)
class Change:
    """Field change with path and value.

    Attributes:
        path: JSON path or field name that changed
        old_value: Previous value (None if newly created)
        new_value: New value
    """

    path: str
    old_value: Value | None
    new_value: Value


@dataclass(frozen=True)
class ApprovalSubject:
    """Subject of approval (exception or action).

    Attributes:
        subject_type: Type of subject - exception or action
        subject_id: Unique identifier for the subject
    """

    subject_type: Literal["exception", "action"]
    subject_id: str


__all__ = [
    "ActorRef",
    "ApprovalSubject",
    "Change",
    "EntityRef",
    "EvidenceRef",
    "Fact",
    "PolicyRef",
    "SourceObjectRef",
    "SourceRef",
    "Value",
    "Violation",
]
