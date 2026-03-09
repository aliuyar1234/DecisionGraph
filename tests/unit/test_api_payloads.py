"""Tests for extracted DecisionGraph API payload builders."""

from decisiongraph.api_payloads import (
    build_approval_recorded_payload,
    build_policy_evaluated_payload,
    build_trace_started_payload,
)
from decisiongraph.domain.types import (
    ActorRef,
    ApprovalSubject,
    EntityRef,
    PolicyRef,
    Violation,
)


def test_build_trace_started_payload_includes_optional_context() -> None:
    payload = build_trace_started_payload(
        workflow="renewal",
        title="Review renewal",
        primary_entity=EntityRef(
            entity_type="account",
            entity_id="acct-123",
            system="crm",
        ),
        context={"region": "eu"},
    )

    assert payload == {
        "workflow": "renewal",
        "title": "Review renewal",
        "primary_entity": {
            "entity_type": "account",
            "entity_id": "acct-123",
            "system": "crm",
        },
        "context": {"region": "eu"},
    }


def test_build_policy_evaluated_payload_omits_empty_optional_fields() -> None:
    payload = build_policy_evaluated_payload(
        policy=PolicyRef(policy_id="discount-cap", policy_version="1.0"),
        inputs=["input-1"],
        decision="allow",
        violations=None,
        explanation=None,
    )

    assert payload == {
        "policy": {"policy_id": "discount-cap", "policy_version": "1.0"},
        "inputs": ["input-1"],
        "decision": "allow",
    }


def test_build_policy_evaluated_payload_serializes_violations() -> None:
    payload = build_policy_evaluated_payload(
        policy=PolicyRef(policy_id="discount-cap", policy_version="1.0"),
        inputs=["input-1"],
        decision="deny",
        violations=[
            Violation(
                code="discount_threshold",
                message="Discount exceeds policy",
                details={"threshold": "12"},
            )
        ],
        explanation={"summary": "Too much discount"},
    )

    assert payload["violations"] == [
        {
            "code": "discount_threshold",
            "message": "Discount exceeds policy",
            "details": {"threshold": "12"},
        }
    ]
    assert payload["explanation"] == {"summary": "Too much discount"}


def test_build_approval_recorded_payload_serializes_actor_subject_and_evidence() -> None:
    payload = build_approval_recorded_payload(
        approval_id="approval-1",
        subject=ApprovalSubject(subject_type="exception", subject_id="exc-1"),
        approver=ActorRef(actor_type="person", actor_id="approver-1"),
        decision="approved",
        reason="Reviewed by finance",
        evidence=[],
    )

    assert payload == {
        "approval_id": "approval-1",
        "subject": {"subject_type": "exception", "subject_id": "exc-1"},
        "approver": {"actor_type": "person", "actor_id": "approver-1"},
        "decision": "approved",
        "reason": "Reviewed by finance",
    }
