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
import sqlite3
from typing import Any


def compute_context_graph_digest(conn: sqlite3.Connection) -> str:
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
    conn.row_factory = sqlite3.Row

    # Get nodes in deterministic order
    nodes_cursor = conn.execute(
        """
        SELECT node_id, node_type, trace_id, log_seq, created_at, metadata_json
        FROM dg_cg_nodes
        ORDER BY node_id
        """
    )

    nodes_data: list[dict[str, Any]] = []
    for row in nodes_cursor.fetchall():
        # Exclude recorded_at (wall-clock) - use created_at (from event.occurred_at)
        nodes_data.append({
            "node_id": row["node_id"],
            "node_type": row["node_type"],
            "trace_id": row["trace_id"],
            "log_seq": row["log_seq"],
            "created_at": row["created_at"],
            "attrs": json.loads(row["metadata_json"]),
        })

    # Get edges in deterministic order
    edges_cursor = conn.execute(
        """
        SELECT edge_id, edge_type, from_node_id, to_node_id, trace_id, log_seq, created_at, metadata_json
        FROM dg_cg_edges
        ORDER BY edge_id
        """
    )

    edges_data: list[dict[str, Any]] = []
    for row in edges_cursor.fetchall():
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


def compute_trace_summary_digest(conn: sqlite3.Connection) -> str:
    """Compute digest over trace summaries.

    Args:
        conn: SQLite connection

    Returns:
        SHA-256 digest prefixed with "sha256:"
    """
    conn.row_factory = sqlite3.Row

    cursor = conn.execute(
        """
        SELECT trace_id, workflow, title, primary_entity_type, primary_entity_id,
               outcome, started_at, finished_at, event_count, last_log_seq
        FROM dg_trace_summary
        ORDER BY trace_id
        """
    )

    summaries: list[dict[str, Any]] = []
    for row in cursor.fetchall():
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

    canonical = json.dumps(summaries, sort_keys=True, separators=(",", ":"))
    digest = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return f"sha256:{digest}"


def compute_precedent_index_digest(conn: sqlite3.Connection) -> str:
    """Compute digest over precedent index.

    Args:
        conn: SQLite connection

    Returns:
        SHA-256 digest prefixed with "sha256:"
    """
    conn.row_factory = sqlite3.Row

    cursor = conn.execute(
        """
        SELECT index_id, trace_id, cited_trace_id, reason, similarity_score,
               log_seq, created_at
        FROM dg_precedent_index
        ORDER BY index_id
        """
    )

    entries: list[dict[str, Any]] = []
    for row in cursor.fetchall():
        entries.append({
            "index_id": row["index_id"],
            "trace_id": row["trace_id"],
            "cited_trace_id": row["cited_trace_id"],
            "reason": row["reason"],
            "similarity_score": row["similarity_score"],
            "log_seq": row["log_seq"],
            "created_at": row["created_at"],
        })

    canonical = json.dumps(entries, sort_keys=True, separators=(",", ":"))
    digest = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return f"sha256:{digest}"


def compute_full_projection_digest(conn: sqlite3.Connection) -> str:
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
