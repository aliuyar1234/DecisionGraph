"""Run a deterministic end-to-end trace and assert projection digests."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from decisiongraph.domain.events import EventEnvelope
from decisiongraph.domain.types import ActorRef, SourceRef
from decisiongraph.projections.digests import (
    compute_context_graph_digest,
    compute_full_projection_digest,
    compute_precedent_index_digest,
    compute_trace_summary_digest,
)
from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.storage.sqlite import SQLiteEventStore

EXPECTED_PATH = Path("demo") / "golden_e2e_expected.json"


def build_events() -> list[EventEnvelope]:
    source = SourceRef(producer_id="demo-service", system="demo", subsystem=None)
    actor = ActorRef(actor_type="agent", actor_id="demo-agent-v1")
    trace_id = "11111111-1111-1111-1111-111111111111"

    def envelope(
        event_id: str,
        trace_seq: int,
        event_type: str,
        occurred_at: str,
        idempotency_key: str,
        payload: dict,
        causation_event_id: str | None = None,
    ) -> EventEnvelope:
        return EventEnvelope(
            event_id=event_id,
            trace_id=trace_id,
            trace_seq=trace_seq,
            event_type=event_type,
            occurred_at=occurred_at,
            source=source,
            actor=actor,
            idempotency_key=idempotency_key,
            payload=payload,
            correlation_id=None,
            causation_event_id=causation_event_id,
            schema_version=1,
            tags=[],
        )

    return [
        envelope(
            "e0000000-0000-0000-0000-000000000001",
            0,
            "TraceStarted",
            "2025-01-01T10:00:00Z",
            "start:acct-42",
            {
                "workflow": "discount_review",
                "title": "Discount review for acct-42",
                "primary_entity": {
                    "entity_type": "account",
                    "entity_id": "acct-42",
                    "system": "crm",
                },
            },
        ),
        envelope(
            "e0000000-0000-0000-0000-000000000002",
            1,
            "InputObserved",
            "2025-01-01T10:00:01Z",
            "input:discount_request",
            {
                "input_id": "input:discount_request",
                "source": {
                    "system": "crm",
                    "object_type": "discount_request",
                    "object_id": "req-42",
                },
                "facts": [
                    {"key": "requested_discount", "value": {"type": "percent", "value": "20"}},
                    {"key": "policy_cap", "value": {"type": "percent", "value": "10"}},
                    {"key": "sev1_last_90d", "value": {"type": "int", "value": "3"}},
                ],
            },
            causation_event_id="e0000000-0000-0000-0000-000000000001",
        ),
        envelope(
            "e0000000-0000-0000-0000-000000000003",
            2,
            "EntityObserved",
            "2025-01-01T10:00:02Z",
            "entity:acct-42",
            {
                "entity": {
                    "entity_type": "account",
                    "entity_id": "acct-42",
                    "system": "crm",
                },
                "role": "primary",
                "facts": [],
            },
            causation_event_id="e0000000-0000-0000-0000-000000000002",
        ),
        envelope(
            "e0000000-0000-0000-0000-000000000004",
            3,
            "PolicyEvaluated",
            "2025-01-01T10:00:03Z",
            "policy_eval:discount_cap@1.0",
            {
                "policy": {"policy_id": "discount_cap", "policy_version": "1.0"},
                "inputs": ["input:discount_request"],
                "decision": "require_exception",
            },
            causation_event_id="e0000000-0000-0000-0000-000000000002",
        ),
        envelope(
            "e0000000-0000-0000-0000-000000000005",
            4,
            "PrecedentCited",
            "2025-01-01T10:00:04Z",
            "prec:discount:prev",
            {
                "cited_trace_id": "22222222-2222-2222-2222-222222222222",
                "reason": "Similar exception approved last quarter.",
            },
            causation_event_id="e0000000-0000-0000-0000-000000000004",
        ),
        envelope(
            "e0000000-0000-0000-0000-000000000006",
            5,
            "ExceptionRequested",
            "2025-01-01T10:00:05Z",
            "exc:req:discount_over_cap",
            {
                "exception_id": "exc:discount_over_cap",
                "policy": {"policy_id": "discount_cap", "policy_version": "1.0"},
                "reason": "Requested 20% exceeds cap 10%.",
            },
            causation_event_id="e0000000-0000-0000-0000-000000000004",
        ),
        envelope(
            "e0000000-0000-0000-0000-000000000007",
            6,
            "ApprovalRecorded",
            "2025-01-01T10:05:00Z",
            "appr:finance:001",
            {
                "approval_id": "appr:finance-001",
                "subject": {
                    "subject_type": "exception",
                    "subject_id": "exc:discount_over_cap",
                },
                "approver": {"actor_type": "person", "actor_id": "vp_finance_42"},
                "decision": "approved",
            },
            causation_event_id="e0000000-0000-0000-0000-000000000006",
        ),
        envelope(
            "e0000000-0000-0000-0000-000000000008",
            7,
            "ActionProposed",
            "2025-01-01T10:05:30Z",
            "action:apply_discount",
            {
                "action_id": "act:apply_discount",
                "action_type": "apply_discount",
                "target_entity": {"entity_type": "account", "entity_id": "acct-42"},
                "target_system": "crm",
                "changes": [{"field": "discount", "value": "20%"}],
            },
            causation_event_id="e0000000-0000-0000-0000-000000000007",
        ),
        envelope(
            "e0000000-0000-0000-0000-000000000009",
            8,
            "ActionCommitted",
            "2025-01-01T10:06:00Z",
            "action:commit:apply_discount",
            {
                "action_id": "act:apply_discount",
                "status": "success",
            },
            causation_event_id="e0000000-0000-0000-0000-000000000008",
        ),
        envelope(
            "e0000000-0000-0000-0000-000000000010",
            9,
            "TraceFinished",
            "2025-01-01T10:06:01Z",
            "finish:acct-42",
            {"outcome": "success"},
            causation_event_id="e0000000-0000-0000-0000-000000000009",
        ),
    ]


def compute_digests(store: SQLiteEventStore) -> dict[str, str]:
    conn = store.connection
    return {
        "context_graph": compute_context_graph_digest(conn),
        "trace_summary": compute_trace_summary_digest(conn),
        "precedent_index": compute_precedent_index_digest(conn),
        "full_projection": compute_full_projection_digest(conn),
    }


def assert_expected(actual: dict[str, str], expected: dict[str, str]) -> None:
    mismatches: dict[str, dict[str, str]] = {}
    for key, expected_value in expected.items():
        actual_value = actual.get(key)
        if actual_value != expected_value:
            mismatches[key] = {
                "expected": expected_value,
                "actual": actual_value or "missing",
            }

    if mismatches:
        print("Digest mismatch:")
        print(json.dumps(mismatches, indent=2, sort_keys=True))
        raise SystemExit(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Run deterministic end-to-end trace and assert digests"
    )
    parser.add_argument(
        "--db",
        type=Path,
        default=None,
        help="Optional SQLite DB path (defaults to in-memory)",
    )
    parser.add_argument(
        "--write-expected",
        action="store_true",
        help="Write expected digest file instead of asserting",
    )
    args = parser.parse_args()

    db_path = ":memory:"
    if args.db is not None:
        db_path = str(args.db)
        if args.db.exists():
            args.db.unlink()
        args.db.parent.mkdir(parents=True, exist_ok=True)

    store = SQLiteEventStore(db_path)
    projector = SQLiteProjector(store.connection)

    for event in build_events():
        store.append_event(event)

    projector.rebuild()
    projector.project_events(store.list_events())

    actual = compute_digests(store)

    if args.write_expected:
        EXPECTED_PATH.parent.mkdir(parents=True, exist_ok=True)
        EXPECTED_PATH.write_text(
            json.dumps(actual, indent=2, sort_keys=True), encoding="utf-8"
        )
        print(f"Wrote expected digests to {EXPECTED_PATH}")
        store.close()
        return

    if not EXPECTED_PATH.exists():
        raise SystemExit(f"Expected digest file missing: {EXPECTED_PATH}")

    expected = json.loads(EXPECTED_PATH.read_text(encoding="utf-8"))
    assert_expected(actual, expected)

    print("Golden E2E digests verified:")
    print(json.dumps(actual, indent=2, sort_keys=True))

    store.close()


if __name__ == "__main__":
    main()
