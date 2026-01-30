"""Tests for storage backend error handling and edge cases.

Covers:
- Idempotency conflict detection
- Trace sequence validation
- Transaction rollback scenarios
- First event must be TraceStarted
- Empty store queries
"""

import pytest

from decisiongraph.domain.events import (
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
    EventEnvelope,
)
from decisiongraph.domain.types import ActorRef, SourceRef
from decisiongraph.errors import (
    DG_ERR_CONFLICT,
    DG_ERR_EVENT_SEQUENCE_INVALID,
    DG_ERR_IDEMPOTENCY_CONFLICT,
    DG_ERR_SCHEMA_VIOLATION,
    DecisionGraphError,
)
from decisiongraph.ids import generate_trace_id
from decisiongraph.testing import InMemoryEventStore, create_test_envelope
from decisiongraph.time import now_rfc3339


class TestIdempotencyConflictDetection:
    """Tests for idempotency conflict detection."""

    def test_same_key_same_payload_returns_existing(self) -> None:
        """Same idempotency key with same payload returns existing event."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()
        payload = {"workflow": "test", "title": "Idempotent"}

        env = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload=payload,
            idempotency_key="idem-123",
        )

        stored1 = store.append_event(env)
        stored2 = store.append_event(env)

        # Should return the same event
        assert stored1.log_seq == stored2.log_seq
        assert stored1.event_id == stored2.event_id

    def test_same_key_different_payload_raises_conflict(self) -> None:
        """Same idempotency key with different payload raises conflict."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Original"},
            idempotency_key="conflict-key",
        )
        store.append_event(env1)

        env2 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Different!"},
            idempotency_key="conflict-key",
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            store.append_event(env2)

        assert exc_info.value.code == DG_ERR_IDEMPOTENCY_CONFLICT
        assert "different payload" in str(exc_info.value)

    def test_same_key_same_payload_different_metadata_conflict(self) -> None:
        """Same idempotency key with different metadata raises conflict."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()
        payload = {"workflow": "test", "title": "Original"}

        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload=payload,
            idempotency_key="meta-key",
            actor_id="actor-1",
            producer_id="producer-1",
        )
        store.append_event(env1)

        env2 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload=payload,
            idempotency_key="meta-key",
            actor_id="actor-2",
            producer_id="producer-1",
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            store.append_event(env2)

        assert exc_info.value.code == DG_ERR_IDEMPOTENCY_CONFLICT
        assert "different metadata" in str(exc_info.value)

    def test_same_key_different_producer_allowed(self) -> None:
        """Same idempotency key from different producers is allowed."""
        store = InMemoryEventStore()
        trace_id1 = generate_trace_id()
        trace_id2 = generate_trace_id()

        env1 = create_test_envelope(
            trace_id=trace_id1,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "From producer 1"},
            idempotency_key="shared-key",
            producer_id="producer-1",
        )
        env2 = create_test_envelope(
            trace_id=trace_id2,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "From producer 2"},
            idempotency_key="shared-key",
            producer_id="producer-2",
        )

        stored1 = store.append_event(env1)
        stored2 = store.append_event(env2)

        # Both events should be stored with different log_seqs
        assert stored1.log_seq != stored2.log_seq

    def test_idempotency_survives_payload_hash_collision_check(self) -> None:
        """Idempotent retry returns correct event even with complex payload."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        # Complex nested payload
        payload = {
            "workflow": "renewal",
            "title": "Complex test",
            "nested": {
                "list": [1, 2, 3, {"inner": "value"}],
                "dict": {"a": "b", "c": "d"},
            },
        }

        env = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload=payload,
            idempotency_key="complex-idem",
        )

        stored1 = store.append_event(env)
        stored2 = store.append_event(env)

        assert stored1.log_seq == stored2.log_seq
        assert stored1.payload == stored2.payload


class TestTraceSequenceValidation:
    """Tests for trace_seq validation rules."""

    def test_first_event_must_be_trace_started(self) -> None:
        """First event (trace_seq=0) must be TraceStarted."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        env = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_ENTITY_OBSERVED,  # Not TraceStarted!
            payload={"entity": {"entity_type": "Test", "entity_id": "1"}},
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            store.append_event(env)

        assert exc_info.value.code == DG_ERR_EVENT_SEQUENCE_INVALID
        assert "First event must be TraceStarted" in str(exc_info.value)

    def test_trace_started_must_have_seq_zero(self) -> None:
        """TraceStarted must have trace_seq=0."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        # First, properly start the trace
        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )
        store.append_event(env0)

        # Try to add TraceStarted with seq=1
        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_TRACE_STARTED,  # TraceStarted again!
            payload={"workflow": "test", "title": "Another start"},
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            store.append_event(env1)

        assert exc_info.value.code == DG_ERR_EVENT_SEQUENCE_INVALID

    def test_trace_seq_must_be_monotonic(self) -> None:
        """trace_seq must increase by exactly 1."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        # Start trace
        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )
        store.append_event(env0)

        # Skip seq=1, try seq=2
        env2 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=2,  # Gap!
            event_type=EVENT_TYPE_ENTITY_OBSERVED,
            payload={"entity": {"entity_type": "Test", "entity_id": "1"}},
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            store.append_event(env2)

        assert exc_info.value.code == DG_ERR_EVENT_SEQUENCE_INVALID
        assert "Expected trace_seq 1" in str(exc_info.value)

    def test_trace_seq_cannot_go_backwards(self) -> None:
        """trace_seq cannot decrease."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        # Start trace and add events with unique idempotency keys
        for i in range(3):
            event_type = (
                EVENT_TYPE_TRACE_STARTED if i == 0 else EVENT_TYPE_ENTITY_OBSERVED
            )
            payload = (
                {"workflow": "test", "title": "Test"}
                if i == 0
                else {"entity": {"entity_type": "Test", "entity_id": str(i)}}
            )
            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=i,
                event_type=event_type,
                payload=payload,
                idempotency_key=f"{trace_id}-seq-{i}",  # Unique key
            )
            store.append_event(env)

        # Try to go backwards with different idempotency key
        env_back = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,  # Already used seq, but different idempotency key
            event_type=EVENT_TYPE_ENTITY_OBSERVED,
            payload={"entity": {"entity_type": "Test", "entity_id": "back"}},
            idempotency_key=f"{trace_id}-backwards",  # Different key
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            store.append_event(env_back)

        assert exc_info.value.code == DG_ERR_EVENT_SEQUENCE_INVALID

    def test_multiple_traces_independent_sequences(self) -> None:
        """Each trace has independent trace_seq counter."""
        store = InMemoryEventStore()
        trace_id1 = generate_trace_id()
        trace_id2 = generate_trace_id()

        # Start first trace
        env1_0 = create_test_envelope(
            trace_id=trace_id1,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Trace 1"},
        )
        store.append_event(env1_0)

        # Start second trace (also seq=0)
        env2_0 = create_test_envelope(
            trace_id=trace_id2,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Trace 2"},
        )
        store.append_event(env2_0)

        # Add to first trace (seq=1)
        env1_1 = create_test_envelope(
            trace_id=trace_id1,
            trace_seq=1,
            event_type=EVENT_TYPE_ENTITY_OBSERVED,
            payload={"entity": {"entity_type": "Test", "entity_id": "1"}},
        )
        store.append_event(env1_1)

        # Add to second trace (also seq=1, independent)
        env2_1 = create_test_envelope(
            trace_id=trace_id2,
            trace_seq=1,
            event_type=EVENT_TYPE_ENTITY_OBSERVED,
            payload={"entity": {"entity_type": "Test", "entity_id": "2"}},
        )
        stored = store.append_event(env2_1)

        assert stored.trace_seq == 1


class TestTraceFinished:
    """Tests for TraceFinished behavior."""

    def test_trace_finished_locks_trace(self) -> None:
        """No events can be added after TraceFinished."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        # Start and finish trace
        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )
        store.append_event(env0)

        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_TRACE_FINISHED,
            payload={"outcome": "success"},
        )
        store.append_event(env1)

        # Try to add more events
        env2 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=2,
            event_type=EVENT_TYPE_ENTITY_OBSERVED,
            payload={"entity": {"entity_type": "Test", "entity_id": "late"}},
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            store.append_event(env2)

        assert exc_info.value.code == DG_ERR_CONFLICT
        assert "already finished" in str(exc_info.value)

    def test_is_trace_finished(self) -> None:
        """is_trace_finished returns correct state."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        # Before start
        assert store.is_trace_finished(trace_id) is False

        # After start
        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )
        store.append_event(env0)
        assert store.is_trace_finished(trace_id) is False

        # After finish
        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_TRACE_FINISHED,
            payload={"outcome": "success"},
        )
        store.append_event(env1)
        assert store.is_trace_finished(trace_id) is True


class TestEmptyStoreQueries:
    """Tests for querying empty stores."""

    def test_empty_store_list_events(self) -> None:
        """list_events on empty store returns empty list."""
        store = InMemoryEventStore()
        events = store.list_events()
        assert events == []

    def test_empty_store_get_trace_events(self) -> None:
        """get_trace_events on empty store returns empty list."""
        store = InMemoryEventStore()
        events = store.get_trace_events("nonexistent-trace")
        assert events == []

    def test_empty_store_get_last_log_seq(self) -> None:
        """get_last_log_seq on empty store returns 0."""
        store = InMemoryEventStore()
        assert store.get_last_log_seq() == 0

    def test_empty_store_get_next_trace_seq(self) -> None:
        """get_next_trace_seq on empty store returns 0."""
        store = InMemoryEventStore()
        assert store.get_next_trace_seq("any-trace") == 0


class TestSchemaValidation:
    """Tests for payload schema validation."""

    def test_missing_required_fields_rejected(self) -> None:
        """Missing required payload fields raise schema violation."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        env = EventEnvelope(
            event_id="evt-missing",
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            occurred_at=now_rfc3339(),
            source=SourceRef(producer_id="producer", system="test"),
            actor=ActorRef(actor_type="agent", actor_id="test"),
            idempotency_key="missing-fields",
            payload={"workflow": "test", "title": "Missing entity"},
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            store.append_event(env)

        assert exc_info.value.code == DG_ERR_SCHEMA_VIOLATION


class TestStoreQueries:
    """Tests for store query edge cases."""

    def test_list_events_filter_combination(self) -> None:
        """Multiple filters applied together."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        for i in range(5):
            event_type = (
                EVENT_TYPE_TRACE_STARTED if i == 0 else EVENT_TYPE_ENTITY_OBSERVED
            )
            payload = (
                {"workflow": "test", "title": "Test"}
                if i == 0
                else {"entity": {"entity_type": "Test", "entity_id": str(i)}}
            )
            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=i,
                event_type=event_type,
                payload=payload,
            )
            store.append_event(env)

        # Filter by event_type AND limit
        events = store.list_events(
            event_type=EVENT_TYPE_ENTITY_OBSERVED, limit=2
        )
        assert len(events) == 2
        for e in events:
            assert e.event_type == EVENT_TYPE_ENTITY_OBSERVED

    def test_list_events_since_and_until(self) -> None:
        """since_log_seq and until_log_seq work together."""
        store = InMemoryEventStore()

        for i in range(5):
            trace_id = generate_trace_id()
            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={"workflow": "test", "title": f"Trace {i}"},
            )
            store.append_event(env)

        # Get events 2-4 (exclusive since, inclusive until)
        events = store.list_events(since_log_seq=1, until_log_seq=4)
        log_seqs = [e.log_seq for e in events]
        assert log_seqs == [2, 3, 4]

    def test_get_trace_events_since_and_limit(self) -> None:
        """since_trace_seq and limit work together."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        for i in range(10):
            event_type = (
                EVENT_TYPE_TRACE_STARTED if i == 0 else EVENT_TYPE_ENTITY_OBSERVED
            )
            payload = (
                {"workflow": "test", "title": "Test"}
                if i == 0
                else {"entity": {"entity_type": "Test", "entity_id": str(i)}}
            )
            env = create_test_envelope(
                trace_id=trace_id,
                trace_seq=i,
                event_type=event_type,
                payload=payload,
            )
            store.append_event(env)

        # Get events after seq=5, limited to 2
        events = store.get_trace_events(trace_id, since_trace_seq=5, limit=2)
        assert len(events) == 2
        assert events[0].trace_seq == 6
        assert events[1].trace_seq == 7


class TestStoreClear:
    """Tests for store clear functionality."""

    def test_clear_resets_all_state(self) -> None:
        """clear() resets all internal state."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        # Add some events
        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )
        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_TRACE_FINISHED,
            payload={"outcome": "success"},
        )
        store.append_event(env0)
        store.append_event(env1)

        assert store.get_last_log_seq() == 2
        assert store.is_trace_finished(trace_id)

        # Clear
        store.clear()

        # Verify all state reset
        assert store.get_last_log_seq() == 0
        assert store.list_events() == []
        assert store.is_trace_finished(trace_id) is False
        assert store.get_next_trace_seq(trace_id) == 0

    def test_clear_allows_reuse_of_trace_id(self) -> None:
        """After clear, same trace_id can be reused."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        env = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Original"},
        )
        store.append_event(env)
        store.clear()

        # Same trace_id should work again
        env2 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Reused"},
        )
        stored = store.append_event(env2)
        assert stored.log_seq == 1  # Starts from 1 again
