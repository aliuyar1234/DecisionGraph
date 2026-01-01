"""Storage backends for DecisionGraph.

This module provides storage abstractions and implementations.
"""

from decisiongraph.storage.interface import EventStore
from decisiongraph.storage.migrations import MigrationEngine
from decisiongraph.storage.sqlite import SQLiteEventStore

# PostgreSQL support is optional (requires psycopg)
try:
    from decisiongraph.storage.postgres import PostgresEventStore

    HAS_POSTGRES = True
except ImportError:
    PostgresEventStore = None  # type: ignore
    HAS_POSTGRES = False

__all__ = ["EventStore", "MigrationEngine", "SQLiteEventStore", "PostgresEventStore", "HAS_POSTGRES"]
