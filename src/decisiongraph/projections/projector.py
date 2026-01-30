"""Main projector implementation per SSOT 6.2.5.

This module provides SQLiteProjector, which transforms events from the
append-only log into queryable projections (context graph, trace summary,
precedent index).
"""

import json
import sqlite3
from collections.abc import Iterable
from typing import Any

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


class SQLiteProjector:
    """SQLite-based projector per SSOT 6.2.5.

    Transforms events into:
    - Context graph (dg_cg_nodes, dg_cg_edges)
    - Trace summary (dg_trace_summary)
    - Precedent index (dg_precedent_index)
    - Cursor tracking (dg_projection_meta)

    Usage:
        projector = SQLiteProjector(conn)
        for event in events:
            projector.project_event(event)
    """

    PROJECTION_NAME = "context_graph"

    def __init__(self, conn: sqlite3.Connection) -> None:
        """Initialize projector with SQLite connection.

        Args:
            conn: SQLite connection with projection tables
        """
        self._conn = conn
        self._conn.row_factory = sqlite3.Row
        self._emitter = ContextGraphEmitter()

        # Initialize cursor from database
        self._cursor = self._load_cursor()

        # Track trace_seq per trace for gap detection
        self._trace_seq_tracker = self._load_trace_seq_tracker(self._cursor)

    @property
    def connection(self) -> sqlite3.Connection:
        """Get the database connection for query operations.

        Returns:
            SQLite connection for executing queries
        """
        return self._conn

    def execute_query(
        self, sql: str, params: Iterable[Any] | None = None
    ) -> list[sqlite3.Row]:
        """Execute a read query with parameters."""
        params_list = list(params) if params is not None else []
        cursor = self._conn.execute(sql, params_list)
        return cursor.fetchall()

    def _load_cursor(self) -> int:
        """Load last_processed_log_seq from dg_projection_meta.

        Returns:
            Last processed log_seq, or 0 if none
        """
        cursor = self._conn.execute(
            """
            SELECT last_processed_log_seq FROM dg_projection_meta
            WHERE projection_name = ?
            """,
            (self.PROJECTION_NAME,),
        )
        row = cursor.fetchone()
        return row["last_processed_log_seq"] if row else 0

    def _load_trace_seq_tracker(self, cursor: int) -> dict[str, int]:
        """Load per-trace next expected trace_seq based on projected cursor."""
        if cursor <= 0:
            return {}

        tracker: dict[str, int] = {}
        rows = self._conn.execute(
            """
            SELECT trace_id, MAX(trace_seq) AS max_seq
            FROM dg_event_log
            WHERE log_seq <= ?
            GROUP BY trace_id
            """,
            (cursor,),
        ).fetchall()
        for row in rows:
            tracker[row["trace_id"]] = int(row["max_seq"]) + 1
        return tracker

    def _save_cursor(self, log_seq: int) -> None:
        """Save cursor to dg_projection_meta.

        Args:
            log_seq: Log sequence to save as cursor
        """
        self._conn.execute(
            """
            INSERT INTO dg_projection_meta (projection_name, last_processed_log_seq, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(projection_name) DO UPDATE SET
                last_processed_log_seq = excluded.last_processed_log_seq,
                updated_at = excluded.updated_at
            """,
            (self.PROJECTION_NAME, log_seq, now_rfc3339()),
        )

    def get_cursor(self) -> int:
        """Get the last_applied_log_seq cursor.

        Returns:
            Last log_seq that was successfully projected, or 0 if none
        """
        return self._cursor

    def project_event(self, event: StoredEvent) -> None:
        """Project a single event into the projections.

        Args:
            event: Stored event to project

        Raises:
            DecisionGraphError: If event fails validation
        """
        prev_cursor = self._cursor
        prev_trace_seq = self._trace_seq_tracker.get(event.trace_id)
        try:
            self._conn.execute("BEGIN")
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
        """Project a single event assuming an active transaction."""
        # Verify payload hash
        expected_hash = compute_payload_hash(event.payload)
        if event.payload_hash != expected_hash:
            raise DecisionGraphError(
                DG_ERR_CONFLICT,
                f"Payload hash mismatch for event {event.event_id}: "
                f"expected {expected_hash}, got {event.payload_hash}",
            )

        # Verify trace_seq is monotonic (no gaps)
        expected_seq = self._check_trace_seq(event)

        # Emit and store context graph nodes/edges
        emission = self._emitter.emit(event)
        for node in emission.nodes:
            self._insert_node(node)
        for edge in emission.edges:
            self._insert_edge(edge)

        # Handle event-specific projections
        if event.event_type == EVENT_TYPE_TRACE_STARTED:
            self._on_trace_started(event)
        elif event.event_type == EVENT_TYPE_TRACE_FINISHED:
            self._on_trace_finished(event)
        elif event.event_type == EVENT_TYPE_POLICY_EVALUATED:
            self._on_policy_evaluated(event)

        # Update trace_seq tracker and cursor
        self._trace_seq_tracker[event.trace_id] = expected_seq + 1
        self._cursor = event.log_seq
        self._save_cursor(event.log_seq)

    def _check_trace_seq(self, event: StoredEvent) -> int:
        """Check that trace_seq is monotonic (no gaps).

        Args:
            event: Event to check

        Raises:
            DecisionGraphError: If trace_seq has gaps
        """
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
        """Insert node into dg_cg_nodes.

        Uses INSERT OR IGNORE to handle duplicates (same node from different events).

        Args:
            node: Node to insert
        """
        attrs_json = json.dumps(node.attrs, sort_keys=True)
        self._conn.execute(
            """
            INSERT OR IGNORE INTO dg_cg_nodes
                (node_id, node_type, trace_id, log_seq, created_at, metadata_json)
            VALUES (?, ?, ?, ?, ?, ?)
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
        """Insert edge into dg_cg_edges.

        Uses INSERT OR IGNORE to handle duplicates.
        Creates placeholder nodes for external references (e.g., cited traces).

        Args:
            edge: Edge to insert
        """
        # Ensure from_node exists (create placeholder if needed)
        self._ensure_node_exists(edge.from_node_id, edge.trace_id, edge.log_seq, edge.created_at)
        # Ensure to_node exists (create placeholder if needed)
        self._ensure_node_exists(edge.to_node_id, edge.trace_id, edge.log_seq, edge.created_at)

        attrs_json = json.dumps(edge.attrs, sort_keys=True)
        self._conn.execute(
            """
            INSERT OR IGNORE INTO dg_cg_edges
                (edge_id, edge_type, from_node_id, to_node_id, trace_id, log_seq, created_at, metadata_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
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
        """Ensure a node exists, creating a placeholder if needed.

        Used when creating edges that reference external nodes (e.g., cited traces).

        Args:
            node_id: Node ID to ensure exists
            trace_id: Trace ID for the placeholder
            log_seq: log_seq for the placeholder
            created_at: created_at for the placeholder
        """
        # Extract node_type from node_id (format: type:id)
        parts = node_id.split(":", 1)
        node_type = parts[0] if len(parts) > 1 else "unknown"
        resolved_trace_id = trace_id
        if node_type == "trace" and len(parts) > 1:
            resolved_trace_id = parts[1]

        self._conn.execute(
            """
            INSERT OR IGNORE INTO dg_cg_nodes
                (node_id, node_type, trace_id, log_seq, created_at, metadata_json)
            VALUES (?, ?, ?, ?, ?, '{}')
            """,
            (node_id, node_type, resolved_trace_id, log_seq, created_at),
        )

    def _on_trace_started(self, event: StoredEvent) -> None:
        """Handle TraceStarted event for trace summary.

        Args:
            event: TraceStarted event
        """
        payload = event.payload
        workflow = payload.get("workflow", "")
        title = payload.get("title", "")

        primary_entity = payload.get("primary_entity", {})
        primary_entity_type = primary_entity.get("entity_type") if primary_entity else None
        primary_entity_id = primary_entity.get("entity_id") if primary_entity else None

        self._conn.execute(
            """
            INSERT INTO dg_trace_summary
                (trace_id, workflow, title, primary_entity_type, primary_entity_id,
                 outcome, started_at, finished_at, event_count, last_log_seq)
            VALUES (?, ?, ?, ?, ?, NULL, ?, NULL, 1, ?)
            ON CONFLICT(trace_id) DO UPDATE SET
                event_count = event_count + 1,
                last_log_seq = excluded.last_log_seq
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
        """Handle PolicyEvaluated event for policy evaluation index."""
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
        self._conn.execute(
            """
            INSERT OR IGNORE INTO dg_policy_eval_index
                (index_id, trace_id, policy_id, policy_version, log_seq, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
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
        """Handle TraceFinished event for trace summary and precedent index.

        Args:
            event: TraceFinished event
        """
        payload = event.payload
        outcome = payload.get("outcome", "success")

        # Update trace summary
        self._conn.execute(
            """
            UPDATE dg_trace_summary
            SET outcome = ?,
                finished_at = ?,
                event_count = event_count + 1,
                last_log_seq = ?
            WHERE trace_id = ?
            """,
            (outcome, event.occurred_at, event.log_seq, event.trace_id),
        )

        # Build precedent index from accumulated events
        self._build_precedent_index(event.trace_id, event.log_seq)

    def _build_precedent_index(self, trace_id: str, _finished_log_seq: int) -> None:
        """Build precedent index entries for a finished trace.

        Indexes PrecedentCited events for fast precedent lookup.

        Args:
            trace_id: Trace ID that finished
            finished_log_seq: log_seq of TraceFinished event
        """
        # Find all PrecedentCited events for this trace
        cursor = self._conn.execute(
            """
            SELECT log_seq, event_id, payload_json, occurred_at FROM dg_event_log
            WHERE trace_id = ? AND event_type = ?
            """,
            (trace_id, EVENT_TYPE_PRECEDENT_CITED),
        )

        entries: list[tuple[str, str, str, str, str | None, int, str]] = []
        for row in cursor.fetchall():
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
            self._conn.executemany(
                """
                INSERT OR IGNORE INTO dg_precedent_index
                    (index_id, trace_id, cited_trace_id, reason, similarity_score,
                     log_seq, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                entries,
            )

    def rebuild(self) -> None:
        """Rebuild projection from scratch.

        Clears existing projections and replays all events.
        """
        # Clear existing projections (edges first due to foreign keys)
        self._conn.execute("DELETE FROM dg_cg_edges")
        self._conn.execute("DELETE FROM dg_cg_nodes")
        self._conn.execute("DELETE FROM dg_precedent_index")
        self._conn.execute("DELETE FROM dg_policy_eval_index")
        self._conn.execute("DELETE FROM dg_trace_summary")
        self._conn.execute(
            "DELETE FROM dg_projection_meta WHERE projection_name = ?",
            (self.PROJECTION_NAME,),
        )

        # Reset cursor and tracker
        self._cursor = 0
        self._trace_seq_tracker.clear()
        self._conn.commit()

    def project_events(
        self, events: list[StoredEvent], batch_size: int | None = None
    ) -> None:
        """Project multiple events in order.

        Args:
            events: List of events to project (must be in log_seq order)
            batch_size: Optional batch size for commits
        """
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
            self._conn.execute("BEGIN")
            for event in events:
                self._project_event_in_tx(event)
            self._conn.commit()
        except Exception:
            self._conn.rollback()
            self._cursor = prev_cursor
            self._trace_seq_tracker = prev_tracker
            raise

    def get_nodes(self, trace_id: str | None = None) -> list[dict[str, Any]]:
        """Get nodes from the context graph.

        Args:
            trace_id: Optional trace ID to filter by

        Returns:
            List of node dicts
        """
        if trace_id:
            cursor = self._conn.execute(
                "SELECT * FROM dg_cg_nodes WHERE trace_id = ? ORDER BY node_id",
                (trace_id,),
            )
        else:
            cursor = self._conn.execute("SELECT * FROM dg_cg_nodes ORDER BY node_id")

        return [dict(row) for row in cursor.fetchall()]

    def get_edges(self, trace_id: str | None = None) -> list[dict[str, Any]]:
        """Get edges from the context graph.

        Args:
            trace_id: Optional trace ID to filter by

        Returns:
            List of edge dicts
        """
        if trace_id:
            cursor = self._conn.execute(
                "SELECT * FROM dg_cg_edges WHERE trace_id = ? ORDER BY edge_id",
                (trace_id,),
            )
        else:
            cursor = self._conn.execute("SELECT * FROM dg_cg_edges ORDER BY edge_id")

        return [dict(row) for row in cursor.fetchall()]

    def get_trace_summary(self, trace_id: str) -> dict[str, Any] | None:
        """Get trace summary.

        Args:
            trace_id: Trace ID to get summary for

        Returns:
            Trace summary dict or None if not found
        """
        cursor = self._conn.execute(
            "SELECT * FROM dg_trace_summary WHERE trace_id = ?",
            (trace_id,),
        )
        row = cursor.fetchone()
        return dict(row) if row else None


__all__ = ["SQLiteProjector"]
