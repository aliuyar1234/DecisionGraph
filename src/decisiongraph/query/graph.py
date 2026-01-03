"""Graph query functions per SSOT 11.10.

This module provides graph query functionality:
- NodeRef: Reference to a graph node
- ContextSubgraph: Scoped subgraph result
- GraphEdgePage: Paginated edge result
- get_context_subgraph: Query scoped subgraph
- list_node_edges: Paginate edges for a node
"""

import json
from collections import deque
from dataclasses import dataclass, replace
from typing import TYPE_CHECKING

from decisiongraph.errors import (
    DG_ERR_INVALID_ARGUMENT,
    DG_ERR_PROJECTION_OUT_OF_DATE,
    DecisionGraphError,
)
from decisiongraph.projections.interfaces import Edge, Node
from decisiongraph.query.constants import MAX_GRAPH_DEPTH
from decisiongraph.query.filters import GraphEdgeCursor, GraphFilter

if TYPE_CHECKING:
    from typing import Literal

    from decisiongraph.projections.projector import SQLiteProjector
    from decisiongraph.storage.interface import EventStore


@dataclass(frozen=True)
class NodeRef:
    """Reference to a graph node per SSOT 7.4.0.

    Attributes:
        node_type: Type of node (trace, entity, policy, etc.)
        node_id: Unique identifier within the node type
    """

    node_type: str
    node_id: str

    @property
    def node_key(self) -> str:
        """Get the full node key in format {node_type}:{node_id}."""
        return f"{self.node_type}:{self.node_id}"


@dataclass(frozen=True)
class ContextSubgraph:
    """Scoped subgraph result per SSOT 7.4.0.

    Attributes:
        center: Center node for the subgraph
        nodes: List of nodes in the subgraph (sorted by node_id)
        edges: List of edges in the subgraph (sorted by edge_id)
        truncated: True if max_nodes or max_edges limit was hit
    """

    center: NodeRef
    nodes: list[Node]
    edges: list[Edge]
    truncated: bool


@dataclass(frozen=True)
class GraphEdgePage:
    """Paginated edge result per SSOT 7.4.0.

    Attributes:
        edges: List of edges for this page (sorted by edge_id)
        next_cursor: Cursor for next page, or None if this is the last page
    """

    edges: list[Edge]
    next_cursor: GraphEdgeCursor | None


def _check_staleness(store: "EventStore", projector: "SQLiteProjector") -> None:
    """Check if projections are up-to-date with event log.

    Args:
        store: Event store to check
        projector: Projector to check

    Raises:
        DecisionGraphError: If projections are stale (DG_ERR_PROJECTION_OUT_OF_DATE)
    """
    projector_seq = projector.get_cursor()
    event_seq = store.get_last_log_seq()

    if projector_seq < event_seq:
        raise DecisionGraphError(
            DG_ERR_PROJECTION_OUT_OF_DATE,
            f"Projections at log_seq={projector_seq}, events at {event_seq}",
        )


def get_context_subgraph(
    store: "EventStore",
    projector: "SQLiteProjector",
    center: NodeRef,
    max_depth: int = 1,
    filter_opts: GraphFilter | None = None,
) -> ContextSubgraph:
    """Get scoped subgraph around a center node per SSOT 7.4.4.

    This query returns a subgraph centered on a specific node, traversing
    up to max_depth edges away. Results are scoped to prevent returning
    the entire graph.

    Args:
        store: Event store (for staleness check)
        projector: Projector with graph data
        center: Center node for the subgraph
        max_depth: Maximum traversal depth (default 1)
        filter_opts: Optional graph filter

    Returns:
        ContextSubgraph with nodes, edges, and truncation flag

    Raises:
        DecisionGraphError: If projections are stale or invalid arguments
    """
    # Check staleness
    _check_staleness(store, projector)

    # Use defaults if no filter provided
    if filter_opts is None:
        filter_opts = GraphFilter(max_depth=max_depth)
    else:
        # Override max_depth if explicitly provided
        if max_depth != 1:
            filter_opts = replace(filter_opts, max_depth=max_depth)

    # Validate max_depth
    if filter_opts.max_depth > MAX_GRAPH_DEPTH:
        raise DecisionGraphError(
            DG_ERR_INVALID_ARGUMENT,
            f"max_depth must be <= {MAX_GRAPH_DEPTH}, got {filter_opts.max_depth}",
        )

    # Access the projector's connection
    conn = projector.connection

    # BFS traversal from center node
    center_key = center.node_key
    visited_nodes: set[str] = set()
    visited_edges: set[str] = set()
    node_queue: deque[tuple[str, int]] = deque()  # (node_id, depth)

    # Add center node
    node_queue.append((center_key, 0))
    visited_nodes.add(center_key)

    truncated = False

    # BFS traversal
    while node_queue and not truncated:
        current_node_id, current_depth = node_queue.popleft()

        # Stop if we've reached max_depth
        if current_depth >= filter_opts.max_depth:
            continue

        # Get edges from this node
        cursor = conn.execute(
            """
            SELECT * FROM dg_cg_edges
            WHERE from_node_id = ? OR to_node_id = ?
            ORDER BY edge_id
            """,
            (current_node_id, current_node_id),
        )

        for row in cursor.fetchall():
            edge_id = row["edge_id"]

            # Check edge type filter
            if filter_opts.edge_types and row["edge_type"] not in filter_opts.edge_types:
                continue

            # Add edge if not visited
            if edge_id not in visited_edges:
                visited_edges.add(edge_id)

                # Check max_edges limit
                if len(visited_edges) > filter_opts.max_edges:
                    truncated = True
                    break

                # Add neighbor nodes to queue
                from_node = row["from_node_id"]
                to_node = row["to_node_id"]

                for neighbor in [from_node, to_node]:
                    if neighbor != current_node_id and neighbor not in visited_nodes:
                        # Check node type filter
                        if filter_opts.node_types:
                            node_type = neighbor.split(":", 1)[0] if ":" in neighbor else ""
                            if node_type not in filter_opts.node_types:
                                continue

                        visited_nodes.add(neighbor)
                        node_queue.append((neighbor, current_depth + 1))

                        # Check max_nodes limit
                        if len(visited_nodes) > filter_opts.max_nodes:
                            truncated = True
                            break

    # Fetch all visited nodes
    nodes: list[Node] = []
    if visited_nodes:
        placeholders = ",".join("?" * len(visited_nodes))
        cursor = conn.execute(
            f"SELECT * FROM dg_cg_nodes WHERE node_id IN ({placeholders}) ORDER BY node_id",
            list(visited_nodes),
        )
        for row in cursor.fetchall():
            nodes.append(
                Node(
                    node_id=row["node_id"],
                    node_type=row["node_type"],
                    trace_id=row["trace_id"],
                    log_seq=row["log_seq"],
                    created_at=row["created_at"],
                    attrs=json.loads(row["metadata_json"]),
                )
            )

    # Fetch all visited edges
    edges: list[Edge] = []
    if visited_edges:
        placeholders = ",".join("?" * len(visited_edges))
        cursor = conn.execute(
            f"SELECT * FROM dg_cg_edges WHERE edge_id IN ({placeholders}) ORDER BY edge_id",
            list(visited_edges),
        )
        for row in cursor.fetchall():
            edges.append(
                Edge(
                    edge_id=row["edge_id"],
                    edge_type=row["edge_type"],
                    from_node_id=row["from_node_id"],
                    to_node_id=row["to_node_id"],
                    trace_id=row["trace_id"],
                    log_seq=row["log_seq"],
                    created_at=row["created_at"],
                    attrs=json.loads(row["metadata_json"]),
                )
            )

    return ContextSubgraph(
        center=center,
        nodes=nodes,
        edges=edges,
        truncated=truncated,
    )


def list_node_edges(
    store: "EventStore",
    projector: "SQLiteProjector",
    node: NodeRef,
    direction: "Literal['outgoing', 'incoming', 'both']" = "both",
    cursor: GraphEdgeCursor | None = None,
    limit: int = 100,
) -> GraphEdgePage:
    """Paginate edges from/to a node per SSOT 7.4.5.

    This query returns edges connected to a node with cursor-based pagination.

    Args:
        store: Event store (for staleness check)
        projector: Projector with graph data
        node: Node to get edges for
        direction: Edge direction to query
        cursor: Optional cursor for pagination
        limit: Maximum edges per page (default 100)

    Returns:
        GraphEdgePage with edges and next cursor

    Raises:
        DecisionGraphError: If projections are stale
    """
    # Check staleness
    _check_staleness(store, projector)

    # Validate limit
    if limit <= 0:
        raise DecisionGraphError(
            DG_ERR_INVALID_ARGUMENT,
            f"limit must be positive, got {limit}",
        )

    # Access the projector's connection
    conn = projector.connection
    node_key = node.node_key

    # Build query based on direction
    if direction == "outgoing":
        where_clause = "from_node_id = ?"
    elif direction == "incoming":
        where_clause = "to_node_id = ?"
    else:  # both
        where_clause = "(from_node_id = ? OR to_node_id = ?)"

    # Add cursor condition if provided
    if cursor:
        where_clause += " AND edge_id > ?"

    # Build query
    query = f"SELECT * FROM dg_cg_edges WHERE {where_clause} ORDER BY edge_id LIMIT ?"

    # Execute query
    params: list[str | int] = []
    if direction == "both":
        params.extend([node_key, node_key])
    else:
        params.append(node_key)

    if cursor:
        params.append(cursor.edge_key)

    params.append(limit + 1)  # Fetch one extra to check if there's a next page

    result = conn.execute(query, params)
    rows = result.fetchall()

    # Convert to Edge objects
    edges: list[Edge] = []
    for row in rows[:limit]:  # Only take up to limit
        edges.append(
            Edge(
                edge_id=row["edge_id"],
                edge_type=row["edge_type"],
                from_node_id=row["from_node_id"],
                to_node_id=row["to_node_id"],
                trace_id=row["trace_id"],
                log_seq=row["log_seq"],
                created_at=row["created_at"],
                attrs=json.loads(row["metadata_json"]),
            )
        )

    # Determine next cursor
    next_cursor = None
    if len(rows) > limit:
        # There's a next page
        last_edge = edges[-1]
        next_cursor = GraphEdgeCursor(edge_key=last_edge.edge_id, direction=direction)

    return GraphEdgePage(
        edges=edges,
        next_cursor=next_cursor,
    )


__all__ = [
    "NodeRef",
    "ContextSubgraph",
    "GraphEdgePage",
    "get_context_subgraph",
    "list_node_edges",
]
