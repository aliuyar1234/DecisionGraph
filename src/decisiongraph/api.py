"""High-level DecisionGraph API.

This module provides the main entry point for using DecisionGraph.
"""

from pathlib import Path
from typing import Any, Literal

from decisiongraph.domain.events import (
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
    EventEnvelope,
    StoredEvent,
)
from decisiongraph.domain.types import ActorRef, EntityRef, SourceRef
from decisiongraph.ids import generate_event_id, generate_trace_id
from decisiongraph.projections.interfaces import ProjectionEngine
from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.query import find_precedents, get_trace_events
from decisiongraph.query.graph import ContextSubgraph, NodeRef, get_context_subgraph
from decisiongraph.query.precedents import PrecedentHit, PrecedentQuery
from decisiongraph.storage.interface import EventStore
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.time import now_rfc3339

# Optional PostgreSQL support
try:
    from decisiongraph.projections.postgres import PostgresProjector
    from decisiongraph.storage.postgres import PostgresEventStore

    HAS_POSTGRES = True
except ImportError:  # pragma: no cover - optional dependency
    PostgresProjector = None  # type: ignore[misc,assignment]
    PostgresEventStore = None  # type: ignore[misc,assignment]
    HAS_POSTGRES = False


class DecisionGraph:
    """High-level DecisionGraph API."""

    def __init__(self, db_path: str | Path) -> None:
        """Initialize DecisionGraph with SQLite backend."""
        self._store: EventStore = SQLiteEventStore(db_path)
        self._projector: ProjectionEngine = SQLiteProjector(self._store.connection)

    @classmethod
    def from_postgres(cls, conninfo: str) -> "DecisionGraph":
        """Initialize DecisionGraph with PostgreSQL backend."""
        if not HAS_POSTGRES or PostgresEventStore is None or PostgresProjector is None:
            raise ImportError(
                "PostgreSQL support requires psycopg. "
                "Install with: pip install decisiongraph[postgres]"
            )

        store = PostgresEventStore(conninfo)
        projector = PostgresProjector(store.connection)
        instance = cls.__new__(cls)
        instance._store = store
        instance._projector = projector
        return instance

    def close(self) -> None:
        """Close the database connection."""
        self._store.close()

    def __enter__(self) -> "DecisionGraph":
        return self

    def __exit__(self, exc_type: Any, exc_val: Any, exc_tb: Any) -> None:
        self.close()

    def _append_event(
        self,
        trace_id: str,
        event_type: str,
        payload: dict[str, Any],
        source: SourceRef,
        actor: ActorRef,
        idempotency_key: str | None = None,
        correlation_id: str | None = None,
        causation_event_id: str | None = None,
        schema_version: int = 1,
        tags: list[str] | None = None,
        occurred_at: str | None = None,
    ) -> StoredEvent:
        trace_seq = self._store.get_next_trace_seq(trace_id)
        event_id = generate_event_id()

        if idempotency_key is None:
            idempotency_key = f"{event_type}:{trace_id}:{trace_seq}"

        envelope = EventEnvelope(
            event_id=event_id,
            trace_id=trace_id,
            trace_seq=trace_seq,
            event_type=event_type,
            occurred_at=occurred_at or now_rfc3339(),
            source=source,
            actor=actor,
            idempotency_key=idempotency_key,
            payload=payload,
            correlation_id=correlation_id,
            causation_event_id=causation_event_id,
            schema_version=schema_version,
            tags=tags or [],
        )

        stored = self._store.append_event(envelope)
        # Skip projection when this is an idempotent replay of an already
        # projected event.
        if stored.log_seq > self._projector.get_cursor():
            self._projector.project_event(stored)
        return stored

    def append_event(
        self,
        trace_id: str,
        event_type: str,
        payload: dict[str, Any],
        source: SourceRef,
        actor: ActorRef,
        idempotency_key: str | None = None,
        correlation_id: str | None = None,
        causation_event_id: str | None = None,
        schema_version: int = 1,
        tags: list[str] | None = None,
        occurred_at: str | None = None,
    ) -> StoredEvent:
        """Append any supported event type."""
        return self._append_event(
            trace_id=trace_id,
            event_type=event_type,
            payload=payload,
            source=source,
            actor=actor,
            idempotency_key=idempotency_key,
            correlation_id=correlation_id,
            causation_event_id=causation_event_id,
            schema_version=schema_version,
            tags=tags,
            occurred_at=occurred_at,
        )

    def start_trace(
        self,
        workflow: str,
        title: str,
        primary_entity: EntityRef,
        source: SourceRef,
        actor: ActorRef,
        context: dict[str, str] | None = None,
        trace_id: str | None = None,
    ) -> str:
        if trace_id is None:
            trace_id = generate_trace_id()

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

        self._append_event(
            trace_id=trace_id,
            event_type=EVENT_TYPE_TRACE_STARTED,
            payload=payload,
            source=source,
            actor=actor,
            idempotency_key=f"start:{trace_id}",
        )
        return trace_id

    def finish_trace(
        self,
        trace_id: str,
        outcome: Literal["success", "failure", "abandoned"],
        source: SourceRef,
        actor: ActorRef,
        summary: str | None = None,
    ) -> StoredEvent:
        payload: dict[str, Any] = {"outcome": outcome}
        if summary:
            payload["summary"] = summary

        return self._append_event(
            trace_id=trace_id,
            event_type=EVENT_TYPE_TRACE_FINISHED,
            payload=payload,
            source=source,
            actor=actor,
            idempotency_key=f"finish:{trace_id}",
        )

    def get_trace_events(self, trace_id: str) -> list[StoredEvent]:
        return get_trace_events(self._store, trace_id=trace_id)

    def get_context_subgraph(
        self,
        node_type: str,
        node_id: str,
        max_depth: int = 1,
    ) -> ContextSubgraph:
        center = NodeRef(node_type=node_type, node_id=node_id)
        return get_context_subgraph(
            self._store, self._projector, center, max_depth=max_depth
        )

    def find_precedents(
        self,
        policy_id: str | None = None,
        policy_version: str | None = None,
        entity_type: str | None = None,
        entity_id: str | None = None,
        outcome: str | None = None,
        limit: int = 100,
    ) -> list[PrecedentHit]:
        query = PrecedentQuery(
            policy_id=policy_id,
            policy_version=policy_version,
            entity_type=entity_type,
            entity_id=entity_id,
            outcome=outcome,
            limit=limit,
        )
        return find_precedents(self._store, self._projector, query)

    def is_trace_finished(self, trace_id: str) -> bool:
        return self._store.is_trace_finished(trace_id)

    def sync_projections(self, batch_size: int | None = None) -> int:
        """Apply any new events to projections."""
        since_log_seq = self._projector.get_cursor()
        events = self._store.list_events(since_log_seq=since_log_seq)
        if events:
            self._projector.project_events(events, batch_size=batch_size)
        return len(events)

    def replay_projections(self, batch_size: int | None = None) -> None:
        """Rebuild projections from scratch."""
        self._projector.rebuild()
        events = self._store.list_events()
        self._projector.project_events(events, batch_size=batch_size)


__all__ = ["DecisionGraph"]
