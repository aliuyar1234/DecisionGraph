"""Query layer constants.

This module defines constants used across the query layer to avoid
magic numbers and provide a single source of truth for limits.
"""

# Maximum number of events that can be returned in a single query
MAX_QUERY_LIMIT = 10000

# Maximum graph traversal depth to prevent runaway queries
MAX_GRAPH_DEPTH = 10


__all__ = [
    "MAX_QUERY_LIMIT",
    "MAX_GRAPH_DEPTH",
]
