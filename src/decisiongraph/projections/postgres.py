"""PostgreSQL projector implementation per SSOT 6.2.5."""

from __future__ import annotations

import json
from collections.abc import Sequence
from typing import Any

try:
    from psycopg import Connection
    from psycopg.rows import dict_row
except ImportError as e:
    raise ImportError(
        "psycopg is required for PostgreSQL projection support. "
        "Install with: pip install decisiongraph[postgres]"
    ) from e

from decisiongraph.domain.events import (
    EVENT_TYPE_POLICY_EVALUATED,
    EVENT_TYPE_PRECEDENT_CITED,
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
    StoredEvent,
)
from decisiongraph.errors import (
    DG_ERR_CONFLICT,
    DG_ERR_EVENT_SEQUENCE_INVALID,
    DG_ERR_INVALID_ARGUMENT,
    DG_ERR_SCHEMA_VIOLATION,
    DecisionGraphError,
)
from decisiongraph.projections.context_graph import ContextGraphEmitter
from decisiongraph.projections.interfaces import Edge, Node
from decisiongraph.serialization import compute_payload_hash
from decisiongraph.time import now_rfc3339


class PostgresProjector:
    """PostgreSQL-based projector per SSOT 6.2.5."""

    PROJECTION_NAME = "context_graph"

    def __init__(self, conn: Connection[Any]) -> None:
        self._conn = conn
        if hasattr(self._conn, "row_factory"):
            self._conn.row_factory = dict_row
        self._emitter = ContextGraphEmitter()
        self._cursor = self._load_cursor()
        self._trace_seq_tracker = self._load_trace_seq_tracker(self._cursor)

    @property
    def connection(self) -> Connection[Any]:
        return self._conn

    def execute_query(
        self, sql: str, params: Sequence[Any] | None = None
    ) -> list[dict[str, Any]]:
        sql = sql.replace("?", "%s")
        with self._conn.cursor() as cur:
            cur.execute(sql, params or ())
            rows = cur.fetchall()
        return [dict(row) for row in rows]

    def _load_cursor(self) -> int:
        rows = self.execute_query(
            """
            SELECT last_processed_log_seq FROM dg_projection_meta
            WHERE projection_name = ?
            """,
            [self.PROJECTION_NAME],
        )
        if not rows:
            return 0
        return int(rows[0]["last_processed_log_seq"])

    def _load_trace_seq_tracker(self, cursor: int) -> dict[str, int]:
        if cursor <= 0:
            return {}
        rows = self.execute_query(
            """
            SELECT trace_id, MAX(trace_seq) AS max_seq
            FROM dg_event_log
            WHERE log_seq <= ?
            GROUP BY trace_id
            """,
            [cursor],
        )
        return {row["trace_id"]: int(row["max_seq"]) + 1 for row in rows}

    def _save_cursor(self, log_seq: int) -> None:
        with self._conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO dg_projection_meta
                    (projection_name, last_processed_log_seq, updated_at)
                VALUES (%s, %s, %s)
                ON CONFLICT (projection_name) DO UPDATE SET
                    last_processed_log_seq = EXCLUDED.last_processed_log_seq,
                    updated_at = EXCLUDED.updated_at
                """,
                (self.PROJECTION_NAME, log_seq, now_rfc3339()),
            )

    def get_cursor(self) -> int:
        return self._cursor

    def project_event(self, event: StoredEvent) -> None:
        prev_cursor = self._cursor
        prev_trace_seq = self._trace_seq_tracker.get(event.trace_id)
        try:
            self._project_event_in_tx(event)
            self._conn.commit()
        except Exception:
            self._conn.rollback()
            self._cursor = prev_cursor
            if prev_trace_seq is None:
                self._trace_seq_tracker.pop(event.trace_id, None)
            else:
                self._trace_seq_tracker[event.trace_id] = prev_trace_seq
            raise

    def _project_event_in_tx(self, event: StoredEvent) -> None:
        expected_hash = compute_payload_hash(event.payload)
        if event.payload_hash != expected_hash:
            raise DecisionGraphError(
                DG_ERR_CONFLICT,
                f"Payload hash mismatch for event {event.event_id}: "
                f"expected {expected_hash}, got {event.payload_hash}",
            )

        expected_seq = self._check_trace_seq(event)

        emission = self._emitter.emit(event)
        for node in emission.nodes:
            self._insert_node(node)
        for edge in emission.edges:
            self._insert_edge(edge)

        if event.event_type == EVENT_TYPE_TRACE_STARTED:
            self._on_trace_started(event)
        elif event.event_type == EVENT_TYPE_TRACE_FINISHED:
            self._on_trace_finished(event)
        elif event.event_type == EVENT_TYPE_POLICY_EVALUATED:
            self._on_policy_evaluated(event)

        self._trace_seq_tracker[event.trace_id] = expected_seq + 1
        self._cursor = event.log_seq
        self._save_cursor(event.log_seq)

    def _check_trace_seq(self, event: StoredEvent) -> int:
        trace_id = event.trace_id
        trace_seq = event.trace_seq

        expected_seq = self._trace_seq_tracker.get(trace_id, 0)

        if trace_seq != expected_seq:
            raise DecisionGraphError(
                DG_ERR_EVENT_SEQUENCE_INVALID,
                f"trace_seq gap in trace {trace_id}: "
                f"expected {expected_seq}, got {trace_seq}",
            )
        return expected_seq

    def _insert_node(self, node: Node) -> None:
        attrs_json = json.dumps(node.attrs, sort_keys=True)
        with self._conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO dg_cg_nodes
                    (node_id, node_type, trace_id, log_seq, created_at, metadata_json)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (node_id) DO NOTHING
                """,
                (
                    node.node_id,
                    node.node_type,
                    node.trace_id,
                    node.log_seq,
                    node.created_at,
                    attrs_json,
                ),
            )

    def _insert_edge(self, edge: Edge) -> None:
        self._ensure_node_exists(edge.from_node_id, edge.trace_id, edge.log_seq, edge.created_at)
        self._ensure_node_exists(edge.to_node_id, edge.trace_id, edge.log_seq, edge.created_at)

        attrs_json = json.dumps(edge.attrs, sort_keys=True)
        with self._conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO dg_cg_edges
                    (edge_id, edge_type, from_node_id, to_node_id, trace_id,
                     log_seq, created_at, metadata_json)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (edge_id) DO NOTHING
                """,
                (
                    edge.edge_id,
                    edge.edge_type,
                    edge.from_node_id,
                    edge.to_node_id,
                    edge.trace_id,
                    edge.log_seq,
                    edge.created_at,
                    attrs_json,
                ),
            )

    def _ensure_node_exists(
        self, node_id: str, trace_id: str, log_seq: int, created_at: str
    ) -> None:
        parts = node_id.split(":", 1)
        node_type = parts[0] if len(parts) > 1 else "unknown"
        resolved_trace_id = trace_id
        if node_type == "trace" and len(parts) > 1:
            resolved_trace_id = parts[1]

        with self._conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO dg_cg_nodes
                    (node_id, node_type, trace_id, log_seq, created_at, metadata_json)
                VALUES (%s, %s, %s, %s, %s, '{}')
                ON CONFLICT (node_id) DO NOTHING
                """,
                (node_id, node_type, resolved_trace_id, log_seq, created_at),
            )

    def _on_trace_started(self, event: StoredEvent) -> None:
        payload = event.payload
        workflow = payload.get("workflow", "")
        title = payload.get("title", "")

        primary_entity = payload.get("primary_entity", {})
        primary_entity_type = primary_entity.get("entity_type") if primary_entity else None
        primary_entity_id = primary_entity.get("entity_id") if primary_entity else None

        with self._conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO dg_trace_summary
                    (trace_id, workflow, title, primary_entity_type, primary_entity_id,
                     outcome, started_at, finished_at, event_count, last_log_seq)
                VALUES (%s, %s, %s, %s, %s, NULL, %s, NULL, 1, %s)
                ON CONFLICT (trace_id) DO UPDATE SET
                    event_count = dg_trace_summary.event_count + 1,
                    last_log_seq = EXCLUDED.last_log_seq
                """,
                (
                    event.trace_id,
                    workflow,
                    title,
                    primary_entity_type,
                    primary_entity_id,
                    event.occurred_at,
                    event.log_seq,
                ),
            )

    def _on_policy_evaluated(self, event: StoredEvent) -> None:
        payload = event.payload
        policy = payload.get("policy", {})
        policy_id = policy.get("policy_id")
        policy_version = policy.get("policy_version")

        if not policy_id or not policy_version:
            raise DecisionGraphError(
                DG_ERR_SCHEMA_VIOLATION,
                "PolicyEvaluated requires policy_id and policy_version",
            )

        index_id = f"{event.trace_id}:{policy_id}:{policy_version}:{event.event_id}"
        with self._conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO dg_policy_eval_index
                    (index_id, trace_id, policy_id, policy_version, log_seq, created_at)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (index_id) DO NOTHING
                """,
                (
                    index_id,
                    event.trace_id,
                    policy_id,
                    policy_version,
                    event.log_seq,
                    event.occurred_at,
                ),
            )

    def _on_trace_finished(self, event: StoredEvent) -> None:
        payload = event.payload
        outcome = payload.get("outcome", "success")

        with self._conn.cursor() as cur:
            cur.execute(
                """
                UPDATE dg_trace_summary
                SET outcome = %s,
                    finished_at = %s,
                    event_count = dg_trace_summary.event_count + 1,
                    last_log_seq = %s
                WHERE trace_id = %s
                """,
                (outcome, event.occurred_at, event.log_seq, event.trace_id),
            )

        self._build_precedent_index(event.trace_id)

    def _build_precedent_index(self, trace_id: str) -> None:
        rows = self.execute_query(
            """
            SELECT log_seq, event_id, payload_json, occurred_at
            FROM dg_event_log
            WHERE trace_id = ? AND event_type = ?
            """,
            [trace_id, EVENT_TYPE_PRECEDENT_CITED],
        )

        entries: list[tuple[str, str, str, str, str | None, int, str]] = []
        for row in rows:
            payload = json.loads(row["payload_json"])
            cited_trace_id = payload.get("cited_trace_id", "")
            reason = payload.get("reason", "")
            similarity_score = payload.get("similarity_score")

            if cited_trace_id:
                index_id = f"{trace_id}:{cited_trace_id}:{row['event_id']}"
                entries.append(
                    (
                        index_id,
                        trace_id,
                        cited_trace_id,
                        reason,
                        similarity_score,
                        row["log_seq"],
                        row["occurred_at"],
                    )
                )

        if entries:
            with self._conn.cursor() as cur:
                cur.executemany(
                    """
                    INSERT INTO dg_precedent_index
                        (index_id, trace_id, cited_trace_id, reason, similarity_score,
                         log_seq, created_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (index_id) DO NOTHING
                    """,
                    entries,
                )

    def rebuild(self) -> None:
        with self._conn.cursor() as cur:
            cur.execute("DELETE FROM dg_cg_edges")
            cur.execute("DELETE FROM dg_cg_nodes")
            cur.execute("DELETE FROM dg_precedent_index")
            cur.execute("DELETE FROM dg_policy_eval_index")
            cur.execute("DELETE FROM dg_trace_summary")
            cur.execute(
                "DELETE FROM dg_projection_meta WHERE projection_name = %s",
                (self.PROJECTION_NAME,),
            )
        self._conn.commit()
        self._cursor = 0
        self._trace_seq_tracker.clear()

    def project_events(
        self, events: list[StoredEvent], batch_size: int | None = None
    ) -> None:
        if not events:
            return

        if batch_size is None:
            self._project_events_in_tx(events)
            return

        if batch_size <= 0:
            raise DecisionGraphError(
                DG_ERR_INVALID_ARGUMENT,
                "batch_size must be positive",
            )

        for i in range(0, len(events), batch_size):
            self._project_events_in_tx(events[i : i + batch_size])

    def _project_events_in_tx(self, events: list[StoredEvent]) -> None:
        prev_cursor = self._cursor
        prev_tracker = dict(self._trace_seq_tracker)
        try:
            for event in events:
                self._project_event_in_tx(event)
            self._conn.commit()
        except Exception:
            self._conn.rollback()
            self._cursor = prev_cursor
            self._trace_seq_tracker = prev_tracker
            raise

    def get_nodes(self, trace_id: str | None = None) -> list[dict[str, Any]]:
        if trace_id:
            rows = self.execute_query(
                "SELECT * FROM dg_cg_nodes WHERE trace_id = ? ORDER BY node_id",
                [trace_id],
            )
        else:
            rows = self.execute_query("SELECT * FROM dg_cg_nodes ORDER BY node_id")
        return [dict(row) for row in rows]

    def get_edges(self, trace_id: str | None = None) -> list[dict[str, Any]]:
        if trace_id:
            rows = self.execute_query(
                "SELECT * FROM dg_cg_edges WHERE trace_id = ? ORDER BY edge_id",
                [trace_id],
            )
        else:
            rows = self.execute_query("SELECT * FROM dg_cg_edges ORDER BY edge_id")
        return [dict(row) for row in rows]

    def get_trace_summary(self, trace_id: str) -> dict[str, Any] | None:
        rows = self.execute_query(
            "SELECT * FROM dg_trace_summary WHERE trace_id = ?",
            [trace_id],
        )
        if not rows:
            return None
        return dict(rows[0])


__all__ = ["PostgresProjector"]
