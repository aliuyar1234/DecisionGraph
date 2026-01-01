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
from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.query import find_precedents, get_trace_events
from decisiongraph.query.graph import ContextSubgraph, NodeRef, get_context_subgraph
from decisiongraph.query.precedents import PrecedentHit, PrecedentQuery
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.time import now_rfc3339


class DecisionGraph:
    """High-level DecisionGraph API."""

    def __init__(self, db_path: str | Path) -> None:
        """Initialize DecisionGraph with SQLite backend."""
        self._store = SQLiteEventStore(db_path)
        self._projector = SQLiteProjector(self._store._conn)

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
            occurred_at=now_rfc3339(),
            source=source,
            actor=actor,
            idempotency_key=idempotency_key,
            payload=payload,
        )

        stored = self._store.append_event(envelope)
        self._projector.project_event(stored)
        return stored

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


__all__ = ["DecisionGraph"]
