"""Migration engine for numbered SQL migrations per DD-015.

This module provides MigrationEngine, which applies numbered .sql migration
files to a database in order.
"""

import re
import sqlite3
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Migration:
    """Represents a single migration file.

    Attributes:
        version: Migration version number (e.g., 1 for 0001_event_log.sql)
        name: Migration name (e.g., "event_log")
        path: Full path to the SQL file
        sql: SQL content to execute
    """

    version: int
    name: str
    path: Path
    sql: str


class MigrationEngine:
    """Applies numbered SQL migrations to a SQLite database.

    Migrations are numbered SQL files in a directory:
        0001_event_log.sql
        0002_projections.sql
        ...

    Each migration runs in a transaction. Applied migrations are tracked
    in the schema_migrations table.

    Usage:
        engine = MigrationEngine(conn, migrations_dir)
        engine.migrate()  # Apply all pending migrations
    """

    SCHEMA_MIGRATIONS_TABLE = "schema_migrations"

    def __init__(self, conn: sqlite3.Connection, migrations_dir: Path) -> None:
        """Initialize migration engine.

        Args:
            conn: SQLite connection
            migrations_dir: Directory containing numbered .sql files
        """
        self._conn = conn
        self._migrations_dir = migrations_dir
        self._ensure_schema_migrations_table()

    def _ensure_schema_migrations_table(self) -> None:
        """Create schema_migrations table if it doesn't exist."""
        self._conn.execute(f"""
            CREATE TABLE IF NOT EXISTS {self.SCHEMA_MIGRATIONS_TABLE} (
                version INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                applied_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
        """)
        self._conn.commit()

    def get_applied_versions(self) -> set[int]:
        """Get set of already-applied migration versions.

        Returns:
            Set of version numbers that have been applied
        """
        cursor = self._conn.execute(
            f"SELECT version FROM {self.SCHEMA_MIGRATIONS_TABLE}"
        )
        return {row[0] for row in cursor.fetchall()}

    def discover_migrations(self) -> list[Migration]:
        """Discover all migration files in the migrations directory.

        Migration files must match pattern: NNNN_name.sql
        where NNNN is a 4-digit version number.

        Returns:
            List of Migration objects sorted by version
        """
        migrations: list[Migration] = []
        pattern = re.compile(r"^(\d{4})_(.+)\.sql$")

        if not self._migrations_dir.exists():
            return migrations

        for path in sorted(self._migrations_dir.glob("*.sql")):
            match = pattern.match(path.name)
            if match:
                version = int(match.group(1))
                name = match.group(2)
                sql = path.read_text(encoding="utf-8")
                migrations.append(Migration(version, name, path, sql))

        return sorted(migrations, key=lambda m: m.version)

    def get_pending_migrations(self) -> list[Migration]:
        """Get migrations that have not been applied yet.

        Returns:
            List of pending Migration objects sorted by version
        """
        applied = self.get_applied_versions()
        all_migrations = self.discover_migrations()
        return [m for m in all_migrations if m.version not in applied]

    def apply_migration(self, migration: Migration) -> None:
        """Apply a single migration in a transaction.

        Args:
            migration: Migration to apply

        Raises:
            sqlite3.Error: If migration SQL fails
        """
        # Execute migration SQL
        self._conn.executescript(migration.sql)

        # Record as applied
        self._conn.execute(
            f"""
            INSERT INTO {self.SCHEMA_MIGRATIONS_TABLE} (version, name)
            VALUES (?, ?)
            """,
            (migration.version, migration.name),
        )
        self._conn.commit()

    def migrate(self) -> list[Migration]:
        """Apply all pending migrations.

        Returns:
            List of migrations that were applied
        """
        pending = self.get_pending_migrations()
        applied: list[Migration] = []

        for migration in pending:
            self.apply_migration(migration)
            applied.append(migration)

        return applied

    def get_current_version(self) -> int:
        """Get the current schema version.

        Returns:
            Highest applied migration version, or 0 if none applied
        """
        cursor = self._conn.execute(
            f"SELECT MAX(version) FROM {self.SCHEMA_MIGRATIONS_TABLE}"
        )
        row = cursor.fetchone()
        return row[0] if row[0] is not None else 0


__all__ = ["Migration", "MigrationEngine"]
