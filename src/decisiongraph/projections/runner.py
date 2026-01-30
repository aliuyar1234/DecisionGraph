"""Projection runner for replaying events on any backend."""

from __future__ import annotations

import sqlite3
from typing import Any

from decisiongraph.projections.digests import compute_full_projection_digest
from decisiongraph.projections.projector import SQLiteProjector


class Projector:
    """Backend-agnostic projector runner."""

    def __init__(self, store: Any) -> None:
        if not hasattr(store, "connection"):
            raise ValueError("store must expose a connection property")

        self._store = store
        self._projector: Any
        conn = store.connection
        if isinstance(conn, sqlite3.Connection):
            self._projector = SQLiteProjector(conn)
        else:
            from decisiongraph.projections.postgres import PostgresProjector

            self._projector = PostgresProjector(conn)

    def run(self) -> None:
        """Rebuild projections from scratch and replay all events."""
        self._projector.rebuild()
        events = self._store.list_events()
        self._projector.project_events(events)

    def get_digest(self) -> str:
        """Get full projection digest."""
        return compute_full_projection_digest(self._projector.connection)


__all__ = ["Projector"]
