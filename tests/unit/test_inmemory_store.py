"""Tests for InMemoryEventStore - TC-P1-005 through TC-P1-010."""

from collections.abc import Callable

import pytest

from decisiongraph.domain.events import (
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
)
from decisiongraph.errors import (
    DG_ERR_CONFLICT,
    DG_ERR_EVENT_SEQUENCE_INVALID,
    DG_ERR_IDEMPOTENCY_CONFLICT,
    DecisionGraphError,
)
from decisiongraph.ids import generate_trace_id
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.testing import InMemoryEventStore, create_test_envelope


class TestAppendEvent:
    """Tests for append_event method."""

    def test_append_returns_log_seq(self) -> None:
        """TC-P1-009: append_event returns StoredEvent with log_seq."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        envelope = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )

        stored = store.append_event(envelope)

        assert stored.log_seq == 1
        assert stored.event_id == envelope.event_id
        assert stored.payload_hash.startswith("sha256:")
        assert stored.recorded_at is not None

    def test_log_seq_increments(self) -> None:
        """log_seq increments with each append."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        # First event
        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )
        stored1 = store.append_event(env1)

        # Second event
        env2 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_ENTITY_OBSERVED,
            payload={"entity": {"entity_type": "Test", "entity_id": "1"}},
        )
        stored2 = store.append_event(env2)

        assert stored1.log_seq == 1
        assert stored2.log_seq == 2


class TestIdempotency:
    """Tests for idempotency behavior."""

    def test_idempotent_repeat_success(self) -> None:
        """TC-P1-005: Same idempotency key + payload returns existing event."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()
        payload = {"workflow": "test", "title": "Test"}

        envelope = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload=payload,
            idempotency_key="my-idem-key",
        )

        # First append
        stored1 = store.append_event(envelope)

        # Second append with same envelope (same idempotency key and payload)
        stored2 = store.append_event(envelope)

        # Should return the same event
        assert stored1.log_seq == stored2.log_seq
        assert stored1.event_id == stored2.event_id

    def test_idempotency_conflict_error(self) -> None:
        """TC-P1-006: Same idempotency key + different payload raises error."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        # First envelope
        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Original"},
            idempotency_key="conflict-key",
        )
        store.append_event(env1)

        # Second envelope with same key but different payload
        env2 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Modified"},  # Different!
            idempotency_key="conflict-key",  # Same key
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            store.append_event(env2)

        assert exc_info.value.code == DG_ERR_IDEMPOTENCY_CONFLICT

    @pytest.mark.parametrize(
        "store_factory",
        [
            lambda: InMemoryEventStore(),
            lambda: SQLiteEventStore(":memory:"),
        ],
    )
    def test_idempotent_retry_ignores_updated_trace_seq(
        self,
        store_factory: Callable[[], InMemoryEventStore | SQLiteEventStore],
    ) -> None:
        """Idempotent retries may reuse a later trace_seq and still return the original."""
        store = store_factory()
        try:
            trace_id = generate_trace_id()
            payload = {"workflow": "test", "title": "Retry"}

            initial = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload=payload,
                idempotency_key="retry-key",
            )
            retry = create_test_envelope(
                trace_id=trace_id,
                trace_seq=1,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload=payload,
                idempotency_key="retry-key",
            )

            stored_initial = store.append_event(initial)
            stored_retry = store.append_event(retry)

            assert stored_retry.log_seq == stored_initial.log_seq
            assert stored_retry.event_id == stored_initial.event_id
        finally:
            if hasattr(store, "close"):
                store.close()


class TestTraceSequence:
    """Tests for trace_seq enforcement."""

    def test_trace_seq_monotonic_enforced(self) -> None:
        """TC-P1-007: trace_seq must be strictly monotonic."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        # Start trace (seq=0)
        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )
        store.append_event(env0)

        # Try to skip seq=1 and go to seq=2
        env2 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=2,  # Skipped 1!
            event_type=EVENT_TYPE_ENTITY_OBSERVED,
            payload={"entity": {"entity_type": "Test", "entity_id": "1"}},
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            store.append_event(env2)

        assert exc_info.value.code == DG_ERR_EVENT_SEQUENCE_INVALID

    def test_trace_started_must_be_seq_zero(self) -> None:
        """TraceStarted must have trace_seq=0."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        env = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,  # Wrong! Should be 0
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            store.append_event(env)

        assert exc_info.value.code == DG_ERR_EVENT_SEQUENCE_INVALID

    def test_first_event_must_be_trace_started(self) -> None:
        """First event in trace must be TraceStarted."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        env = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,  # Correct seq
            event_type=EVENT_TYPE_ENTITY_OBSERVED,  # Wrong type!
            payload={"entity": {"entity_type": "Test", "entity_id": "1"}},
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            store.append_event(env)

        assert exc_info.value.code == DG_ERR_EVENT_SEQUENCE_INVALID


class TestTraceFinish:
    """Tests for TraceFinished behavior."""

    def test_trace_finish_locks(self) -> None:
        """TC-P1-008: No events after TraceFinished."""
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

        # Finish trace
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
            payload={"entity": {"entity_type": "Test", "entity_id": "1"}},
        )

        with pytest.raises(DecisionGraphError) as exc_info:
            store.append_event(env2)

        assert exc_info.value.code == DG_ERR_CONFLICT

    def test_is_trace_finished(self) -> None:
        """is_trace_finished returns correct status."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        assert not store.is_trace_finished(trace_id)

        # Start trace
        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )
        store.append_event(env0)

        assert not store.is_trace_finished(trace_id)

        # Finish trace
        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_TRACE_FINISHED,
            payload={"outcome": "success"},
        )
        store.append_event(env1)

        assert store.is_trace_finished(trace_id)


class TestGetTraceEvents:
    """Tests for get_trace_events method."""

    def test_get_trace_events_ordered(self) -> None:
        """TC-P1-010: Events are ordered by trace_seq."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        # Add events
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

        # Get events
        events = store.get_trace_events(trace_id)

        assert len(events) == 5
        assert [e.trace_seq for e in events] == [0, 1, 2, 3, 4]

    def test_get_trace_events_since(self) -> None:
        """Filter by since_trace_seq."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

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
            )
            store.append_event(env)

        events = store.get_trace_events(trace_id, since_trace_seq=0)

        assert len(events) == 2
        assert events[0].trace_seq == 1
        assert events[1].trace_seq == 2

    def test_get_trace_events_limit(self) -> None:
        """Limit number of events returned."""
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

        events = store.get_trace_events(trace_id, limit=2)

        assert len(events) == 2


class TestListEvents:
    """Tests for list_events method."""

    def test_list_events_ordered(self) -> None:
        """Events are ordered by log_seq."""
        store = InMemoryEventStore()

        # Create two traces
        trace1 = generate_trace_id()
        trace2 = generate_trace_id()

        env1 = create_test_envelope(
            trace_id=trace1,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Trace 1"},
        )
        env2 = create_test_envelope(
            trace_id=trace2,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Trace 2"},
        )

        store.append_event(env1)
        store.append_event(env2)

        events = store.list_events()

        assert len(events) == 2
        assert events[0].log_seq < events[1].log_seq

    def test_list_events_filter_by_type(self) -> None:
        """Filter by event type."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        env0 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )
        env1 = create_test_envelope(
            trace_id=trace_id,
            trace_seq=1,
            event_type=EVENT_TYPE_ENTITY_OBSERVED,
            payload={"entity": {"entity_type": "Test", "entity_id": "1"}},
        )

        store.append_event(env0)
        store.append_event(env1)

        events = store.list_events(event_type=EVENT_TYPE_TRACE_STARTED)

        assert len(events) == 1
        assert events[0].event_type == EVENT_TYPE_TRACE_STARTED


class TestGetLastLogSeq:
    """Tests for get_last_log_seq method."""

    def test_empty_store(self) -> None:
        """Empty store returns 0."""
        store = InMemoryEventStore()
        assert store.get_last_log_seq() == 0

    def test_with_events(self) -> None:
        """Returns highest log_seq."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

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
            )
            store.append_event(env)

        assert store.get_last_log_seq() == 3


class TestClear:
    """Tests for clear method."""

    def test_clear_removes_all(self) -> None:
        """Clear removes all events."""
        store = InMemoryEventStore()
        trace_id = generate_trace_id()

        env = create_test_envelope(
            trace_id=trace_id,
            trace_seq=0,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload={"workflow": "test", "title": "Test"},
        )
        store.append_event(env)

        assert store.get_last_log_seq() == 1

        store.clear()

        assert store.get_last_log_seq() == 0
        assert store.list_events() == []
