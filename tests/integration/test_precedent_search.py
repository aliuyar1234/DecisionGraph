"""Integration tests for precedent search per SSOT 8.1 (TC-P5-010, TC-P5-011).

This module tests:
- Precedent search by policy_id, entity, outcome
- Deduplication and ordering
- Exclusion of unfinished traces
"""


from decisiongraph.domain.events import (
    EVENT_TYPE_POLICY_EVALUATED,
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
)
from decisiongraph.ids import generate_trace_id
from decisiongraph.projections import SQLiteProjector
from decisiongraph.query import PrecedentQuery, find_precedents
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.testing import create_test_envelope


class TestPrecedentSearch:
    """Test precedent search functionality."""

    def test_precedent_search_by_policy(self) -> None:
        """TC-P5-010: find_precedents filters by policy_id correctly."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)

            # Create multiple finished traces with different policies
            for i in range(3):
                trace_id = generate_trace_id()

                # Start trace
                env1 = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=0,
                    event_type=EVENT_TYPE_TRACE_STARTED,
                    payload={
                        "workflow": "test",
                        "title": f"Test {i}",
                        "primary_entity": {
                            "entity_type": "Account",
                            "entity_id": f"acc-{i}",
                        },
                    },
                )
                event1 = store.append_event(env1)
                projector.project_event(event1)

                # Evaluate policy
                policy_id = "policy-A" if i < 2 else "policy-B"
                env2 = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=1,
                    event_type=EVENT_TYPE_POLICY_EVALUATED,
                    payload={
                        "policy": {"policy_id": policy_id, "policy_version": "1.0"},
                        "inputs": [],
                        "decision": "allow",
                    },
                )
                event2 = store.append_event(env2)
                projector.project_event(event2)

                # Finish trace
                env3 = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=2,
                    event_type=EVENT_TYPE_TRACE_FINISHED,
                    payload={"outcome": "approved", "summary": "Done"},
                )
                event3 = store.append_event(env3)
                projector.project_event(event3)

            # Search for precedents by policy-A
            query = PrecedentQuery(policy_id="policy-A")
            precedents = find_precedents(store, projector, query)

            # Should find 2 traces with policy-A
            assert len(precedents) == 2
            for hit in precedents:
                assert hit.policy_id == "policy-A"
                assert hit.outcome == "approved"

    def test_precedent_search_dedup_order(self) -> None:
        """TC-P5-011: find_precedents deduplicates by trace_id and orders by recency."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)

            # Create 3 finished traces
            trace_ids = []
            for i in range(3):
                trace_id = generate_trace_id()
                trace_ids.append(trace_id)

                # Start trace
                env1 = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=0,
                    event_type=EVENT_TYPE_TRACE_STARTED,
                    payload={
                        "workflow": "test",
                        "title": f"Test {i}",
                        "primary_entity": {
                            "entity_type": "Account",
                            "entity_id": f"acc-{i}",
                        },
                    },
                )
                event1 = store.append_event(env1)
                projector.project_event(event1)

                # Finish trace
                env2 = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=1,
                    event_type=EVENT_TYPE_TRACE_FINISHED,
                    payload={"outcome": "approved", "summary": "Done"},
                )
                event2 = store.append_event(env2)
                projector.project_event(event2)

            # Search for all precedents
            query = PrecedentQuery(outcome="approved")
            precedents = find_precedents(store, projector, query)

            # Should find 3 traces
            assert len(precedents) == 3

            # Each trace should appear exactly once (deduplicated)
            returned_trace_ids = [p.trace_id for p in precedents]
            assert len(returned_trace_ids) == len(set(returned_trace_ids))

            # Should be ordered by recency (most recent first)
            # Most recent trace should be first
            assert precedents[0].trace_id == trace_ids[2]

    def test_precedent_search_by_entity(self) -> None:
        """Test find_precedents filters by entity_type and entity_id."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)

            # Create traces with different entities
            for i in range(2):
                trace_id = generate_trace_id()

                env1 = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=0,
                    event_type=EVENT_TYPE_TRACE_STARTED,
                    payload={
                        "workflow": "test",
                        "title": f"Test {i}",
                        "primary_entity": {
                            "entity_type": "Account" if i == 0 else "Contact",
                            "entity_id": f"ent-{i}",
                        },
                    },
                )
                event1 = store.append_event(env1)
                projector.project_event(event1)

                env2 = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=1,
                    event_type=EVENT_TYPE_TRACE_FINISHED,
                    payload={"outcome": "approved", "summary": "Done"},
                )
                event2 = store.append_event(env2)
                projector.project_event(event2)

            # Search by entity type
            query = PrecedentQuery(entity_type="Account")
            precedents = find_precedents(store, projector, query)

            assert len(precedents) == 1
            # Precedent hit doesn't include entity info - that's in trace_summary
            assert precedents[0].workflow == "test"

    def test_unfinished_traces_excluded(self) -> None:
        """Test that find_precedents only returns finished traces."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)

            # Create finished trace
            trace1 = generate_trace_id()
            env1 = create_test_envelope(
                trace_id=trace1,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "test",
                    "title": "Finished",
                    "primary_entity": {"entity_type": "Account", "entity_id": "acc-1"},
                },
            )
            event1 = store.append_event(env1)
            projector.project_event(event1)

            env2 = create_test_envelope(
                trace_id=trace1,
                trace_seq=1,
                event_type=EVENT_TYPE_TRACE_FINISHED,
                payload={"outcome": "approved", "summary": "Done"},
            )
            event2 = store.append_event(env2)
            projector.project_event(event2)

            # Create unfinished trace
            trace2 = generate_trace_id()
            env3 = create_test_envelope(
                trace_id=trace2,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "test",
                    "title": "Unfinished",
                    "primary_entity": {"entity_type": "Account", "entity_id": "acc-2"},
                },
            )
            event3 = store.append_event(env3)
            projector.project_event(event3)

            # Search - should only find finished trace
            query = PrecedentQuery(entity_type="Account")
            precedents = find_precedents(store, projector, query)

            assert len(precedents) == 1
            assert precedents[0].trace_id == trace1
