"""PostgreSQL storage backend for DecisionGraph.

This module provides PostgresEventStore, which implements the EventStore protocol
using PostgreSQL as the persistence layer.
"""

from decisiongraph.storage.postgres.backend import PostgresEventStore

__all__ = ["PostgresEventStore"]
