"""High-level DecisionGraph API.

This module provides the main entry point for using DecisionGraph.
"""

from pathlib import Path
from typing import Any, Literal

from decisiongraph.api_payloads import (
    build_action_committed_payload,
    build_action_proposed_payload,
    build_approval_recorded_payload,
    build_entity_observed_payload,
    build_exception_requested_payload,
    build_input_observed_payload,
    build_policy_evaluated_payload,
    build_precedent_cited_payload,
    build_trace_finished_payload,
    build_trace_started_payload,
)
from decisiongraph.domain.events import (
    EVENT_TYPE_ACTION_COMMITTED,
    EVENT_TYPE_ACTION_PROPOSED,
    EVENT_TYPE_APPROVAL_RECORDED,
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_EXCEPTION_REQUESTED,
    EVENT_TYPE_INPUT_OBSERVED,
    EVENT_TYPE_POLICY_EVALUATED,
    EVENT_TYPE_PRECEDENT_CITED,
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
    EventEnvelope,
    StoredEvent,
)
from decisiongraph.domain.types import (
    ActorRef,
    ApprovalSubject,
    Change,
    EntityRef,
    EvidenceRef,
    Fact,
    PolicyRef,
    SourceObjectRef,
    SourceRef,
    Violation,
)
from decisiongraph.errors import DG_ERR_INVALID_ARGUMENT, DecisionGraphError
from decisiongraph.ids import generate_event_id, generate_trace_id
from decisiongraph.projections.interfaces import ProjectionEngine
from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.query import (
    find_precedents,
    get_projection_health,
    get_trace_events,
)
from decisiongraph.query.graph import ContextSubgraph, NodeRef, get_context_subgraph
from decisiongraph.query.health import ProjectionHealth
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

    DEFAULT_PROJECTION_BATCH_SIZE = 1000

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

    def _project_through_log_seq(self, target_log_seq: int) -> None:
        """Catch projections up through target_log_seq (inclusive)."""
        cursor = self._projector.get_cursor()
        if target_log_seq <= cursor:
            return

        self._project_event_batches(
            since_log_seq=cursor,
            until_log_seq=target_log_seq,
            batch_size=self.DEFAULT_PROJECTION_BATCH_SIZE,
        )

    def _resolve_projection_batch_size(self, batch_size: int | None) -> int:
        """Normalize projection batch size and reject invalid values."""
        if batch_size is None:
            return self.DEFAULT_PROJECTION_BATCH_SIZE
        if batch_size <= 0:
            raise DecisionGraphError(
                DG_ERR_INVALID_ARGUMENT,
                "batch_size must be positive",
            )
        return batch_size

    def _project_event_batches(
        self,
        *,
        since_log_seq: int,
        until_log_seq: int | None = None,
        batch_size: int | None = None,
    ) -> int:
        """Project matching events in bounded batches."""
        resolved_batch_size = self._resolve_projection_batch_size(batch_size)
        processed = 0
        for events in self._store.iter_event_batches(
            since_log_seq=since_log_seq,
            until_log_seq=until_log_seq,
            batch_size=resolved_batch_size,
        ):
            self._projector.project_events(events)
            processed += len(events)
        return processed

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
        self._project_through_log_seq(stored.log_seq)
        return stored

    def _append_structured_event(
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
        """Append a typed helper payload via the generic append path."""
        return self.append_event(
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

        payload = build_trace_started_payload(workflow, title, primary_entity, context)

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
        payload = build_trace_finished_payload(outcome, summary)

        return self._append_event(
            trace_id=trace_id,
            event_type=EVENT_TYPE_TRACE_FINISHED,
            payload=payload,
            source=source,
            actor=actor,
            idempotency_key=f"finish:{trace_id}",
        )

    def observe_input(
        self,
        trace_id: str,
        input_id: str,
        input_source: SourceObjectRef,
        facts: list[Fact],
        source: SourceRef,
        actor: ActorRef,
        idempotency_key: str | None = None,
        correlation_id: str | None = None,
        causation_event_id: str | None = None,
        schema_version: int = 1,
        tags: list[str] | None = None,
        occurred_at: str | None = None,
    ) -> StoredEvent:
        payload = build_input_observed_payload(input_id, input_source, facts)
        return self._append_structured_event(
            trace_id,
            EVENT_TYPE_INPUT_OBSERVED,
            payload,
            source,
            actor,
            idempotency_key,
            correlation_id,
            causation_event_id,
            schema_version,
            tags,
            occurred_at,
        )

    def observe_entity(
        self,
        trace_id: str,
        entity: EntityRef,
        role: Literal["primary", "related"],
        facts: list[Fact],
        source: SourceRef,
        actor: ActorRef,
        idempotency_key: str | None = None,
        correlation_id: str | None = None,
        causation_event_id: str | None = None,
        schema_version: int = 1,
        tags: list[str] | None = None,
        occurred_at: str | None = None,
    ) -> StoredEvent:
        payload = build_entity_observed_payload(entity, role, facts)
        return self._append_structured_event(
            trace_id,
            EVENT_TYPE_ENTITY_OBSERVED,
            payload,
            source,
            actor,
            idempotency_key,
            correlation_id,
            causation_event_id,
            schema_version,
            tags,
            occurred_at,
        )

    def evaluate_policy(
        self,
        trace_id: str,
        policy: PolicyRef,
        inputs: list[str],
        decision: Literal["allow", "deny", "require_exception"],
        source: SourceRef,
        actor: ActorRef,
        violations: list[Violation] | None = None,
        explanation: dict[str, Any] | None = None,
        idempotency_key: str | None = None,
        correlation_id: str | None = None,
        causation_event_id: str | None = None,
        schema_version: int = 1,
        tags: list[str] | None = None,
        occurred_at: str | None = None,
    ) -> StoredEvent:
        payload = build_policy_evaluated_payload(
            policy,
            inputs,
            decision,
            violations,
            explanation,
        )
        return self._append_structured_event(
            trace_id,
            EVENT_TYPE_POLICY_EVALUATED,
            payload,
            source,
            actor,
            idempotency_key,
            correlation_id,
            causation_event_id,
            schema_version,
            tags,
            occurred_at,
        )

    def request_exception(
        self,
        trace_id: str,
        exception_id: str,
        policy: PolicyRef,
        reason: str,
        source: SourceRef,
        actor: ActorRef,
        evidence: list[EvidenceRef] | None = None,
        idempotency_key: str | None = None,
        correlation_id: str | None = None,
        causation_event_id: str | None = None,
        schema_version: int = 1,
        tags: list[str] | None = None,
        occurred_at: str | None = None,
    ) -> StoredEvent:
        payload = build_exception_requested_payload(
            exception_id,
            policy,
            reason,
            evidence,
        )
        return self._append_structured_event(
            trace_id,
            EVENT_TYPE_EXCEPTION_REQUESTED,
            payload,
            source,
            actor,
            idempotency_key,
            correlation_id,
            causation_event_id,
            schema_version,
            tags,
            occurred_at,
        )

    def record_approval(
        self,
        trace_id: str,
        approval_id: str,
        subject: ApprovalSubject,
        approver: ActorRef,
        decision: Literal["approved", "rejected"],
        source: SourceRef,
        actor: ActorRef,
        reason: str | None = None,
        evidence: list[EvidenceRef] | None = None,
        idempotency_key: str | None = None,
        correlation_id: str | None = None,
        causation_event_id: str | None = None,
        schema_version: int = 1,
        tags: list[str] | None = None,
        occurred_at: str | None = None,
    ) -> StoredEvent:
        payload = build_approval_recorded_payload(
            approval_id,
            subject,
            approver,
            decision,
            reason,
            evidence,
        )
        return self._append_structured_event(
            trace_id,
            EVENT_TYPE_APPROVAL_RECORDED,
            payload,
            source,
            actor,
            idempotency_key,
            correlation_id,
            causation_event_id,
            schema_version,
            tags,
            occurred_at,
        )

    def cite_precedent(
        self,
        trace_id: str,
        cited_trace_id: str,
        reason: str,
        source: SourceRef,
        actor: ActorRef,
        similarity_score: str | None = None,
        idempotency_key: str | None = None,
        correlation_id: str | None = None,
        causation_event_id: str | None = None,
        schema_version: int = 1,
        tags: list[str] | None = None,
        occurred_at: str | None = None,
    ) -> StoredEvent:
        payload = build_precedent_cited_payload(
            cited_trace_id,
            reason,
            similarity_score,
        )
        return self._append_structured_event(
            trace_id,
            EVENT_TYPE_PRECEDENT_CITED,
            payload,
            source,
            actor,
            idempotency_key,
            correlation_id,
            causation_event_id,
            schema_version,
            tags,
            occurred_at,
        )

    def propose_action(
        self,
        trace_id: str,
        action_id: str,
        action_type: str,
        target_entity: EntityRef,
        target_system: str,
        changes: list[Change],
        source: SourceRef,
        actor: ActorRef,
        idempotency_key: str | None = None,
        correlation_id: str | None = None,
        causation_event_id: str | None = None,
        schema_version: int = 1,
        tags: list[str] | None = None,
        occurred_at: str | None = None,
    ) -> StoredEvent:
        payload = build_action_proposed_payload(
            action_id,
            action_type,
            target_entity,
            target_system,
            changes,
        )
        return self._append_structured_event(
            trace_id,
            EVENT_TYPE_ACTION_PROPOSED,
            payload,
            source,
            actor,
            idempotency_key,
            correlation_id,
            causation_event_id,
            schema_version,
            tags,
            occurred_at,
        )

    def commit_action(
        self,
        trace_id: str,
        action_id: str,
        status: Literal["success", "failure", "partial"],
        source: SourceRef,
        actor: ActorRef,
        external_reference: str | None = None,
        error: str | None = None,
        idempotency_key: str | None = None,
        correlation_id: str | None = None,
        causation_event_id: str | None = None,
        schema_version: int = 1,
        tags: list[str] | None = None,
        occurred_at: str | None = None,
    ) -> StoredEvent:
        payload = build_action_committed_payload(
            action_id,
            status,
            external_reference,
            error,
        )
        return self._append_structured_event(
            trace_id,
            EVENT_TYPE_ACTION_COMMITTED,
            payload,
            source,
            actor,
            idempotency_key,
            correlation_id,
            causation_event_id,
            schema_version,
            tags,
            occurred_at,
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

    def get_projection_health(
        self,
        include_digests: bool = False,
    ) -> ProjectionHealth:
        return get_projection_health(
            self._store,
            self._projector,
            include_digests=include_digests,
        )

    def is_trace_finished(self, trace_id: str) -> bool:
        return self._store.is_trace_finished(trace_id)

    def sync_projections(self, batch_size: int | None = None) -> int:
        """Apply any new events to projections."""
        since_log_seq = self._projector.get_cursor()
        return self._project_event_batches(
            since_log_seq=since_log_seq,
            batch_size=batch_size,
        )

    def replay_projections(self, batch_size: int | None = None) -> None:
        """Rebuild projections from scratch."""
        self._projector.rebuild()
        self._project_event_batches(
            since_log_seq=0,
            batch_size=batch_size,
        )


__all__ = ["DecisionGraph"]
