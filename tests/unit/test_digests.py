"""Tests for projection digests."""


from decisiongraph.domain.events import (
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_TRACE_STARTED,
)
from decisiongraph.ids import generate_trace_id
from decisiongraph.projections import (
    SQLiteProjector,
    compute_context_graph_digest,
    compute_full_projection_digest,
    compute_trace_summary_digest,
)
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.testing import create_test_envelope


class TestDigestComputation:
    """Tests for digest computation functions."""

    def test_context_graph_digest_format(self) -> None:
        """Digest has sha256: prefix."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store._conn)

            trace_id = generate_trace_id()
            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
            )
            event = store.append_event(env)
            projector.project_event(event)

            digest = compute_context_graph_digest(store._conn)
            assert digest.startswith("sha256:")
            assert len(digest) == 7 + 64  # "sha256:" + 64 hex chars

    def test_digest_stable_across_rebuilds(self) -> None:
        """TC-P3-002: Digest identical across rebuilds."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store._conn)

            # Create some events
            trace_id = generate_trace_id()
            events = []

            env0 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
            )
            events.append(store.append_event(env0))

            env1 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_ENTITY_OBSERVED,
                payload={
                    "entity": {"entity_type": "Account", "entity_id": "acc-1"},
                    "role": "primary",
                    "facts": [],
                },
            )
            events.append(store.append_event(env1))

            # Project all events
            for event in events:
                projector.project_event(event)

            digest1 = compute_context_graph_digest(store._conn)

            # Rebuild
            projector.rebuild()
            for event in events:
                projector.project_event(event)

            digest2 = compute_context_graph_digest(store._conn)

            assert digest1 == digest2

    def test_digest_ignores_recorded_at(self) -> None:
        """TC-P3-012: Digest ignores recorded_at (wall-clock)."""
        # Create two stores with same events but potentially different recorded_at
        with (
            SQLiteEventStore(":memory:") as store1,
            SQLiteEventStore(":memory:") as store2,
        ):
            projector1 = SQLiteProjector(store1._conn)
            projector2 = SQLiteProjector(store2._conn)

            trace_id = generate_trace_id()

            # Same event data
            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
            )

            event1 = store1.append_event(env)
            event2 = store2.append_event(env)

            projector1.project_event(event1)
            projector2.project_event(event2)

            digest1 = compute_context_graph_digest(store1._conn)
            digest2 = compute_context_graph_digest(store2._conn)

            # Digests should be identical because we use occurred_at not recorded_at
            assert digest1 == digest2

    def test_different_events_different_digest(self) -> None:
        """Different events produce different digests."""
        with (
            SQLiteEventStore(":memory:") as store1,
            SQLiteEventStore(":memory:") as store2,
        ):
            projector1 = SQLiteProjector(store1._conn)
            projector2 = SQLiteProjector(store2._conn)

            trace_id1 = generate_trace_id()
            trace_id2 = generate_trace_id()

            env1 = create_test_envelope(
                trace_id=trace_id1,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test 1"},
            )
            env2 = create_test_envelope(
                trace_id=trace_id2,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test 2"},
            )

            event1 = store1.append_event(env1)
            event2 = store2.append_event(env2)

            projector1.project_event(event1)
            projector2.project_event(event2)

            digest1 = compute_context_graph_digest(store1._conn)
            digest2 = compute_context_graph_digest(store2._conn)

            assert digest1 != digest2

    def test_trace_summary_digest(self) -> None:
        """Trace summary digest works."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store._conn)

            trace_id = generate_trace_id()

            env0 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "renewal", "title": "Test Trace"},
            )
            event0 = store.append_event(env0)
            projector.project_event(event0)

            digest = compute_trace_summary_digest(store._conn)
            assert digest.startswith("sha256:")

    def test_full_projection_digest(self) -> None:
        """Full projection digest combines all projections."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store._conn)

            trace_id = generate_trace_id()

            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
            )
            event = store.append_event(env)
            projector.project_event(event)

            digest = compute_full_projection_digest(store._conn)
            assert digest.startswith("sha256:")


class TestProjectionAttrsEmpty:
    """Tests for attrs_json being empty."""

    def test_node_attrs_are_empty_in_db(self) -> None:
        """TC-P3-013: projection attrs are empty."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store._conn)

            trace_id = generate_trace_id()
            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": "Test"},
            )
            event = store.append_event(env)
            projector.project_event(event)

            nodes = projector.get_nodes()
            for node in nodes:
                assert node["metadata_json"] == "{}"

    def test_edge_attrs_are_empty_in_db(self) -> None:
        """TC-P3-013: projection attrs are empty."""
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store._conn)

            trace_id = generate_trace_id()

            env0 = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "test",
                    "title": "Test",
                    "primary_entity": {"entity_type": "Account", "entity_id": "acc-1"},
                },
            )
            event0 = store.append_event(env0)
            projector.project_event(event0)

            edges = projector.get_edges()
            for edge in edges:
                assert edge["metadata_json"] == "{}"
