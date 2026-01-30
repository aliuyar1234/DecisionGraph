"""Projection engine for building read models from events.

This module provides:
- SQLite/PostgreSQL projectors for transforming events into projections
- Context graph (nodes/edges) for decision visualization
- Trace summaries for precedent search
- Precedent index for fast lookups
- Digest computation for determinism verification
"""

from decisiongraph.projections.context_graph import (
    ContextGraphEmitter,
    GraphEmission,
    make_edge_id,
    make_node_id,
)
from decisiongraph.projections.digests import (
    compute_context_graph_digest,
    compute_full_projection_digest,
    compute_precedent_index_digest,
    compute_trace_summary_digest,
)
from decisiongraph.projections.interfaces import (
    ALL_EDGE_TYPES,
    ALL_NODE_TYPES,
    EDGE_TYPE_ACTION_TARGETS_ENTITY,
    EDGE_TYPE_EXCEPTION_APPROVED_BY,
    EDGE_TYPE_TRACE_CITED_PRECEDENT,
    EDGE_TYPE_TRACE_COMMITTED_ACTION,
    EDGE_TYPE_TRACE_EVALUATED_POLICY,
    EDGE_TYPE_TRACE_INVOLVES_ENTITY,
    EDGE_TYPE_TRACE_OBSERVED_INPUT,
    EDGE_TYPE_TRACE_PROPOSED_ACTION,
    EDGE_TYPE_TRACE_REQUESTED_EXCEPTION,
    NODE_TYPE_ACTION,
    NODE_TYPE_ACTOR,
    NODE_TYPE_ENTITY,
    NODE_TYPE_EXCEPTION,
    NODE_TYPE_INPUT,
    NODE_TYPE_POLICY,
    NODE_TYPE_TRACE,
    Edge,
    Node,
    ProjectionBackend,
    ProjectionBuilder,
    ProjectionEngine,
)
from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.projections.runner import Projector

# Optional PostgreSQL projector
try:
    from decisiongraph.projections.postgres import PostgresProjector

    HAS_POSTGRES = True
except ImportError:  # pragma: no cover - optional dependency
    PostgresProjector = None  # type: ignore[misc,assignment]
    HAS_POSTGRES = False

__all__ = [
    # Node types
    "NODE_TYPE_TRACE",
    "NODE_TYPE_ENTITY",
    "NODE_TYPE_INPUT",
    "NODE_TYPE_POLICY",
    "NODE_TYPE_EXCEPTION",
    "NODE_TYPE_ACTION",
    "NODE_TYPE_ACTOR",
    "ALL_NODE_TYPES",
    # Edge types
    "EDGE_TYPE_TRACE_INVOLVES_ENTITY",
    "EDGE_TYPE_TRACE_OBSERVED_INPUT",
    "EDGE_TYPE_TRACE_EVALUATED_POLICY",
    "EDGE_TYPE_TRACE_REQUESTED_EXCEPTION",
    "EDGE_TYPE_EXCEPTION_APPROVED_BY",
    "EDGE_TYPE_TRACE_CITED_PRECEDENT",
    "EDGE_TYPE_TRACE_PROPOSED_ACTION",
    "EDGE_TYPE_TRACE_COMMITTED_ACTION",
    "EDGE_TYPE_ACTION_TARGETS_ENTITY",
    "ALL_EDGE_TYPES",
    # Dataclasses
    "Node",
    "Edge",
    "GraphEmission",
    # Protocol
    "ProjectionBuilder",
    "ProjectionBackend",
    "ProjectionEngine",
    # Runner
    "Projector",
    # Implementation
    "SQLiteProjector",
    "PostgresProjector",
    "HAS_POSTGRES",
    "ContextGraphEmitter",
    # Helpers
    "make_node_id",
    "make_edge_id",
    # Digests
    "compute_context_graph_digest",
    "compute_trace_summary_digest",
    "compute_precedent_index_digest",
    "compute_full_projection_digest",
]
