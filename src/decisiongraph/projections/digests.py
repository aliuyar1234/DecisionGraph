"""Digest computation for projections per SSOT 6.2.7.

This module computes deterministic digests over projection tables
for verifying replay correctness.

Key rules:
- Exclude recorded_at (wall-clock time)
- attrs_json/metadata_json MUST be {} for digest stability
- Sort rows by deterministic key
- Canonical JSON encoding
- SHA-256 hash
"""

import hashlib
import json
from collections.abc import Iterable
from typing import Any, cast

try:
    import sqlite3
except ImportError:  # pragma: no cover - sqlite3 is stdlib
    sqlite3 = None  # type: ignore[assignment]


def _fetch_rows(
    conn: Any, sql: str, params: Iterable[Any] | None = None
) -> list[Any]:
    if hasattr(conn, "execute"):
        cursor = conn.execute(sql, params or [])
        return cast(list[Any], cursor.fetchall())
    with conn.cursor() as cur:
        cur.execute(sql, params or [])
        return cast(list[Any], cur.fetchall())


def compute_context_graph_digest(conn: Any) -> str:
    """Compute digest over context graph (nodes + edges).

    Digest is computed as:
    1. Get all nodes sorted by node_id
    2. Get all edges sorted by edge_id
    3. Build canonical JSON for each
    4. Concatenate and hash

    Args:
        conn: SQLite connection

    Returns:
        SHA-256 digest prefixed with "sha256:"
    """
    if sqlite3 is not None and isinstance(conn, sqlite3.Connection):
        conn.row_factory = sqlite3.Row

    # Get nodes in deterministic order
    nodes_rows = _fetch_rows(
        conn,
        """
        SELECT node_id, node_type, trace_id, log_seq, created_at, metadata_json
        FROM dg_cg_nodes
        ORDER BY node_id
        """
    )

    nodes_data: list[dict[str, Any]] = []
    for row in nodes_rows:
        # Exclude recorded_at (wall-clock) - use created_at (from event.occurred_at)
        nodes_data.append({
            "node_id": row["node_id"],
            "node_type": row["node_type"],
            "trace_id": row["trace_id"],
            "log_seq": row["log_seq"],
            "created_at": row["created_at"],
            "attrs": json.loads(row["metadata_json"]),
        })
    nodes_data.sort(key=lambda item: item["node_id"])

    # Get edges in deterministic order
    edges_rows = _fetch_rows(
        conn,
        """
        SELECT edge_id, edge_type, from_node_id, to_node_id, trace_id, log_seq, created_at, metadata_json
        FROM dg_cg_edges
        ORDER BY edge_id
        """
    )

    edges_data: list[dict[str, Any]] = []
    for row in edges_rows:
        edges_data.append({
            "edge_id": row["edge_id"],
            "edge_type": row["edge_type"],
            "from_node_id": row["from_node_id"],
            "to_node_id": row["to_node_id"],
            "trace_id": row["trace_id"],
            "log_seq": row["log_seq"],
            "created_at": row["created_at"],
            "attrs": json.loads(row["metadata_json"]),
        })
    edges_data.sort(key=lambda item: item["edge_id"])

    # Build canonical representation
    digest_input = {
        "nodes": nodes_data,
        "edges": edges_data,
    }

    # Canonical JSON: sorted keys, no whitespace
    canonical = json.dumps(digest_input, sort_keys=True, separators=(",", ":"))

    # SHA-256 hash
    digest = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return f"sha256:{digest}"


def compute_trace_summary_digest(conn: Any) -> str:
    """Compute digest over trace summaries.

    Args:
        conn: SQLite connection

    Returns:
        SHA-256 digest prefixed with "sha256:"
    """
    if sqlite3 is not None and isinstance(conn, sqlite3.Connection):
        conn.row_factory = sqlite3.Row

    rows = _fetch_rows(
        conn,
        """
        SELECT trace_id, workflow, title, primary_entity_type, primary_entity_id,
               outcome, started_at, finished_at, event_count, last_log_seq
        FROM dg_trace_summary
        ORDER BY trace_id
        """
    )

    summaries: list[dict[str, Any]] = []
    for row in rows:
        # Exclude any wall-clock times, use event times only
        summaries.append({
            "trace_id": row["trace_id"],
            "workflow": row["workflow"],
            "title": row["title"],
            "primary_entity_type": row["primary_entity_type"],
            "primary_entity_id": row["primary_entity_id"],
            "outcome": row["outcome"],
            "started_at": row["started_at"],
            "finished_at": row["finished_at"],
            "event_count": row["event_count"],
            "last_log_seq": row["last_log_seq"],
        })
    summaries.sort(key=lambda item: item["trace_id"])

    canonical = json.dumps(summaries, sort_keys=True, separators=(",", ":"))
    digest = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return f"sha256:{digest}"


def compute_precedent_index_digest(conn: Any) -> str:
    """Compute digest over precedent index.

    Args:
        conn: SQLite connection

    Returns:
        SHA-256 digest prefixed with "sha256:"
    """
    if sqlite3 is not None and isinstance(conn, sqlite3.Connection):
        conn.row_factory = sqlite3.Row

    rows = _fetch_rows(
        conn,
        """
        SELECT source_event_id, log_seq, trace_id, policy_id, policy_version,
               exception_id, primary_entity_type, primary_entity_system, primary_entity_id
        FROM dg_precedent_index
        ORDER BY source_event_id
        """
    )

    entries: list[dict[str, Any]] = []
    for row in rows:
        entries.append({
            "source_event_id": row["source_event_id"],
            "log_seq": row["log_seq"],
            "trace_id": row["trace_id"],
            "policy_id": row["policy_id"],
            "policy_version": row["policy_version"],
            "exception_id": row["exception_id"],
            "primary_entity_type": row["primary_entity_type"],
            "primary_entity_system": row["primary_entity_system"],
            "primary_entity_id": row["primary_entity_id"],
        })
    entries.sort(key=lambda item: item["source_event_id"])

    canonical = json.dumps(entries, sort_keys=True, separators=(",", ":"))
    digest = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return f"sha256:{digest}"


def compute_full_projection_digest(conn: Any) -> str:
    """Compute digest over all projections.

    Combines context graph + trace summary + precedent index.

    Args:
        conn: SQLite connection

    Returns:
        SHA-256 digest prefixed with "sha256:"
    """
    graph_digest = compute_context_graph_digest(conn)
    summary_digest = compute_trace_summary_digest(conn)
    precedent_digest = compute_precedent_index_digest(conn)

    # Combine digests
    combined = f"{graph_digest}:{summary_digest}:{precedent_digest}"
    digest = hashlib.sha256(combined.encode("utf-8")).hexdigest()
    return f"sha256:{digest}"


__all__ = [
    "compute_context_graph_digest",
    "compute_trace_summary_digest",
    "compute_precedent_index_digest",
    "compute_full_projection_digest",
]
