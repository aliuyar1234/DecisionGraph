"""Query layer for events, graph, and precedent search per SSOT 11.8-11.11.

This module provides query APIs for:
- Event queries: list_events, get_trace_events, get_trace_summary
- Graph queries: get_context_subgraph, list_node_edges
- Precedent search: find_precedents

All queries enforce deterministic ordering and staleness checks where appropriate.
"""

# Filter types
# Event query types and functions
from decisiongraph.query.events import (
    TraceSummary,
    get_trace_events,
    get_trace_summary,
    list_events,
)
from decisiongraph.query.filters import (
    EventFilter,
    GraphEdgeCursor,
    GraphFilter,
)

# Graph query types and functions
from decisiongraph.query.graph import (
    ContextSubgraph,
    GraphEdgePage,
    NodeRef,
    get_context_subgraph,
    list_node_edges,
)

# Precedent search types and functions
from decisiongraph.query.precedents import (
    PrecedentHit,
    PrecedentQuery,
    find_precedents,
)

__all__ = [
    # Filters
    "EventFilter",
    "GraphFilter",
    "GraphEdgeCursor",
    # Event queries
    "TraceSummary",
    "get_trace_summary",
    "get_trace_events",
    "list_events",
    # Graph queries
    "NodeRef",
    "ContextSubgraph",
    "GraphEdgePage",
    "get_context_subgraph",
    "list_node_edges",
    # Precedent search
    "PrecedentQuery",
    "PrecedentHit",
    "find_precedents",
]
