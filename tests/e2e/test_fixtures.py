"""E2E tests for golden fixtures per SSOT P6.

Test cases TC-P6-001 through TC-P6-010.
"""

from pathlib import Path

import pytest

from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.query import (
    get_context_subgraph,
    get_trace_events,
)
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.testing.golden import (
    discover_fixture_dirs,
    load_fixture,
    validate_fixture,
)

FIXTURES_DIR = Path(__file__).parent.parent / "golden"
FIXTURE_DIRS = discover_fixture_dirs(FIXTURES_DIR)


@pytest.mark.parametrize("fixture_dir", FIXTURE_DIRS, ids=lambda path: path.name)
def test_all_fixture_digests_match_expected(fixture_dir: Path) -> None:
    """Every checked-in golden fixture must match its digest snapshot."""
    all_match, mismatches = validate_fixture(fixture_dir)
    assert all_match, f"{fixture_dir.name} digest mismatches: {mismatches}"


class TestRenewalFixture:
    """Tests for renewal scenario (SSOT 10.1)."""

    def test_fixture_renewal_digest(self) -> None:
        """TC-P6-001: Renewal scenario digest matches expected."""
        fixture_dir = FIXTURES_DIR / "renewal"
        all_match, mismatches = validate_fixture(fixture_dir)

        assert all_match, f"Digest mismatches: {mismatches}"

    def test_fixture_renewal_queries(self) -> None:
        """TC-P6-002: Renewal queries return expected results."""
        fixture_dir = FIXTURES_DIR / "renewal"
        fixture = load_fixture(fixture_dir)

        # Create in-memory database and replay
        store = SQLiteEventStore(":memory:")
        conn = store.connection
        projector = SQLiteProjector(conn)

        for envelope in fixture.events:
            store.append_event(envelope)

        projector.rebuild()
        all_events = store.list_events()
        projector.project_events(all_events)

        # Query 1: get_trace_events returns 9 events in correct order

        events = get_trace_events(store, trace_id=fixture.trace_id)

        assert len(events) == 9, f"Expected 9 events, got {len(events)}"

        event_types = [e.event_type for e in events]
        expected_types = [
            "TraceStarted",
            "EntityObserved",
            "InputObserved",
            "PolicyEvaluated",
            "PrecedentCited",
            "ExceptionRequested",
            "ApprovalRecorded",
            "ActionCommitted",
            "TraceFinished",
        ]
        assert event_types == expected_types, f"Event type order mismatch: {event_types}"

        # Query 2: Verify context graph query works (even if empty for this fixture)
        from decisiongraph.query import NodeRef

        # Try querying for an account node
        center = NodeRef(node_type="account", node_id="salesforce:sf:acct:001")
        subgraph = get_context_subgraph(store, projector, center=center, max_depth=2)

        # The query should work (even if returning empty results)
        assert isinstance(subgraph.nodes, list)
        assert isinstance(subgraph.edges, list)

        # Query 3: Verify precedent citation
        # The renewal fixture has a PrecedentCited event - verify it's indexed
        precedent_events = [e for e in events if e.event_type == "PrecedentCited"]
        assert len(precedent_events) == 1, "Expected 1 PrecedentCited event"
        assert (
            precedent_events[0].payload["cited_trace_id"]
            == "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        ), "Cited trace ID mismatch"


class TestSupportFixture:
    """Tests for support escalation scenario (SSOT 10.2)."""

    def test_fixture_support_digest(self) -> None:
        """TC-P6-003: Support scenario digest matches expected."""
        fixture_dir = FIXTURES_DIR / "support"
        all_match, mismatches = validate_fixture(fixture_dir)

        assert all_match, f"Digest mismatches: {mismatches}"

    def test_fixture_support_queries(self) -> None:
        """TC-P6-004: Support queries return expected results."""
        fixture_dir = FIXTURES_DIR / "support"
        fixture = load_fixture(fixture_dir)

        # Create in-memory database and replay
        store = SQLiteEventStore(":memory:")
        conn = store.connection
        projector = SQLiteProjector(conn)

        for envelope in fixture.events:
            store.append_event(envelope)

        projector.rebuild()
        all_events = store.list_events()
        projector.project_events(all_events)

        # Query 1: get_trace_events returns expected events

        events = get_trace_events(store, trace_id=fixture.trace_id)

        assert len(events) == 8, f"Expected 8 events, got {len(events)}"

        # Verify cross-system synthesis: ARR, escalations, churn-risk
        input_events = [e for e in events if e.event_type == "InputObserved"]
        assert len(input_events) == 3, f"Expected 3 InputObserved events, got {len(input_events)}"

        # Query 2: Verify ActionCommitted for escalation
        action_events = [e for e in events if e.event_type == "ActionCommitted"]
        assert len(action_events) == 1, "Expected 1 ActionCommitted event"
        assert action_events[0].payload["action_id"] == "act:escalate_tier3"


class TestDealdeskFixture:
    """Tests for deal desk scenario (SSOT 10.3)."""

    def test_fixture_dealdesk_digest(self) -> None:
        """TC-P6-005: Deal Desk scenario digest matches expected."""
        fixture_dir = FIXTURES_DIR / "dealdesk"
        all_match, mismatches = validate_fixture(fixture_dir)

        assert all_match, f"Digest mismatches: {mismatches}"

    def test_fixture_dealdesk_queries(self) -> None:
        """TC-P6-006: Deal Desk queries return expected results."""
        fixture_dir = FIXTURES_DIR / "dealdesk"
        fixture = load_fixture(fixture_dir)

        # Create in-memory database and replay
        store = SQLiteEventStore(":memory:")
        conn = store.connection
        projector = SQLiteProjector(conn)

        for envelope in fixture.events:
            store.append_event(envelope)

        projector.rebuild()
        all_events = store.list_events()
        projector.project_events(all_events)

        # Query 1: get_trace_events returns expected events

        events = get_trace_events(store, trace_id=fixture.trace_id)

        assert len(events) == 9, f"Expected 9 events, got {len(events)}"

        # Query 2: Verify PrecedentCited event exists
        precedent_events = [e for e in events if e.event_type == "PrecedentCited"]
        assert len(precedent_events) == 1, "Expected 1 PrecedentCited event"

        cited_trace_id = precedent_events[0].payload["cited_trace_id"]
        assert cited_trace_id == "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee", "Cited trace ID mismatch"

        # Query 3: Verify ExceptionRequested with healthcare rationale
        exception_events = [e for e in events if e.event_type == "ExceptionRequested"]
        assert len(exception_events) == 1, "Expected 1 ExceptionRequested event"

        reason = exception_events[0].payload["reason"]
        assert "healthcare" in reason.lower(), "Expected healthcare-related reason"


class TestReleaseRejectedFixture:
    """Tests for failed release-review scenario (SSOT 10.4)."""

    def test_fixture_release_rejected_queries(self) -> None:
        fixture = load_fixture(FIXTURES_DIR / "release_rejected")

        store = SQLiteEventStore(":memory:")
        conn = store.connection
        projector = SQLiteProjector(conn)

        for envelope in fixture.events:
            store.append_event(envelope)

        projector.rebuild()
        projector.project_events(store.list_events())

        events = get_trace_events(store, trace_id=fixture.trace_id)
        event_types = [event.event_type for event in events]

        assert event_types == [
            "TraceStarted",
            "EntityObserved",
            "InputObserved",
            "PolicyEvaluated",
            "ActionProposed",
            "ApprovalRecorded",
            "TraceFinished",
        ]

        approval = next(event for event in events if event.event_type == "ApprovalRecorded")
        assert approval.payload["decision"] == "rejected"
        assert approval.payload["subject"]["subject_type"] == "action"

        finished = next(event for event in events if event.event_type == "TraceFinished")
        assert finished.payload["outcome"] == "failure"

        store.close()


class TestSyncFailureFixture:
    """Tests for sync failure scenario (SSOT 10.5)."""

    def test_fixture_sync_failure_queries(self) -> None:
        fixture = load_fixture(FIXTURES_DIR / "sync_failure")

        store = SQLiteEventStore(":memory:")
        conn = store.connection
        projector = SQLiteProjector(conn)

        for envelope in fixture.events:
            store.append_event(envelope)

        projector.rebuild()
        projector.project_events(store.list_events())

        events = get_trace_events(store, trace_id=fixture.trace_id)
        event_types = [event.event_type for event in events]

        assert event_types == [
            "TraceStarted",
            "EntityObserved",
            "InputObserved",
            "PolicyEvaluated",
            "ActionProposed",
            "ActionCommitted",
            "TraceFinished",
        ]

        committed = next(event for event in events if event.event_type == "ActionCommitted")
        assert committed.payload["status"] == "failure"
        assert committed.payload["error"] == "billing API timeout"

        finished = next(event for event in events if event.event_type == "TraceFinished")
        assert finished.payload["outcome"] == "abandoned"

        store.close()


class TestChainOfThought:
    """Tests for chain-of-thought detection per SSOT 13."""

    def test_no_chain_of_thought(self) -> None:
        """TC-P6-010: No chain-of-thought content in fixtures."""
        from decisiongraph.testing.golden import validate_no_chain_of_thought

        for fixture_dir in FIXTURE_DIRS:
            fixture = load_fixture(fixture_dir)

            violations = validate_no_chain_of_thought(fixture)

            assert len(violations) == 0, (
                f"{fixture_dir.name} fixture has CoT violations: {violations}"
            )
