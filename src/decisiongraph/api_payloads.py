"""Internal payload builders for the high-level DecisionGraph API."""

from __future__ import annotations

from dataclasses import asdict
from typing import Any, Literal

from decisiongraph.domain.types import (
    ActorRef,
    ApprovalSubject,
    Change,
    EntityRef,
    EvidenceRef,
    Fact,
    PolicyRef,
    SourceObjectRef,
    Violation,
)


def build_trace_started_payload(
    workflow: str,
    title: str,
    primary_entity: EntityRef,
    context: dict[str, str] | None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "workflow": workflow,
        "title": title,
        "primary_entity": {
            "entity_type": primary_entity.entity_type,
            "entity_id": primary_entity.entity_id,
            "system": primary_entity.system,
        },
    }
    if context:
        payload["context"] = context
    return payload


def build_trace_finished_payload(
    outcome: Literal["success", "failure", "abandoned"],
    summary: str | None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {"outcome": outcome}
    if summary:
        payload["summary"] = summary
    return payload


def build_input_observed_payload(
    input_id: str,
    input_source: SourceObjectRef,
    facts: list[Fact],
) -> dict[str, Any]:
    return {
        "input_id": input_id,
        "source": asdict(input_source),
        "facts": [asdict(fact) for fact in facts],
    }


def build_entity_observed_payload(
    entity: EntityRef,
    role: Literal["primary", "related"],
    facts: list[Fact],
) -> dict[str, Any]:
    return {
        "entity": asdict(entity),
        "role": role,
        "facts": [asdict(fact) for fact in facts],
    }


def build_policy_evaluated_payload(
    policy: PolicyRef,
    inputs: list[str],
    decision: Literal["allow", "deny", "require_exception"],
    violations: list[Violation] | None,
    explanation: dict[str, Any] | None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "policy": asdict(policy),
        "inputs": inputs,
        "decision": decision,
    }
    if violations:
        payload["violations"] = [asdict(violation) for violation in violations]
    if explanation:
        payload["explanation"] = explanation
    return payload


def build_exception_requested_payload(
    exception_id: str,
    policy: PolicyRef,
    reason: str,
    evidence: list[EvidenceRef] | None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "exception_id": exception_id,
        "policy": asdict(policy),
        "reason": reason,
    }
    if evidence:
        payload["evidence"] = [asdict(item) for item in evidence]
    return payload


def build_approval_recorded_payload(
    approval_id: str,
    subject: ApprovalSubject,
    approver: ActorRef,
    decision: Literal["approved", "rejected"],
    reason: str | None,
    evidence: list[EvidenceRef] | None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "approval_id": approval_id,
        "subject": asdict(subject),
        "approver": asdict(approver),
        "decision": decision,
    }
    if reason is not None:
        payload["reason"] = reason
    if evidence:
        payload["evidence"] = [asdict(item) for item in evidence]
    return payload


def build_precedent_cited_payload(
    cited_trace_id: str,
    reason: str,
    similarity_score: str | None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "cited_trace_id": cited_trace_id,
        "reason": reason,
    }
    if similarity_score is not None:
        payload["similarity_score"] = similarity_score
    return payload


def build_action_proposed_payload(
    action_id: str,
    action_type: str,
    target_entity: EntityRef,
    target_system: str,
    changes: list[Change],
) -> dict[str, Any]:
    return {
        "action_id": action_id,
        "action_type": action_type,
        "target_entity": asdict(target_entity),
        "target_system": target_system,
        "changes": [asdict(change) for change in changes],
    }


def build_action_committed_payload(
    action_id: str,
    status: Literal["success", "failure", "partial"],
    external_reference: str | None,
    error: str | None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "action_id": action_id,
        "status": status,
    }
    if external_reference is not None:
        payload["external_reference"] = external_reference
    if error is not None:
        payload["error"] = error
    return payload
