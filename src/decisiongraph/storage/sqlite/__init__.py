"""SQLite storage backend for DecisionGraph.

This module provides SQLiteEventStore, which implements the EventStore protocol
using SQLite as the persistence layer.
"""

from decisiongraph.storage.sqlite.backend import SQLiteEventStore

__all__ = ["SQLiteEventStore"]
