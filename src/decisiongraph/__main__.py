"""DecisionGraph CLI - Read-only inspection tools per SSOT P6.

Usage:
    python -m decisiongraph replay <db>
    python -m decisiongraph projection-status <db> [--include-digests]
    python -m decisiongraph dump-trace <db> <trace_id> [--include-payload]

All CLI operations are read-only and do not modify the database.
"""

import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path

from decisiongraph.domain.events import StoredEvent
from decisiongraph.projections.digests import (
    compute_context_graph_digest,
    compute_full_projection_digest,
    compute_precedent_index_digest,
    compute_trace_summary_digest,
)
from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.query import get_projection_health, get_trace_events
from decisiongraph.storage.sqlite import SQLiteEventStore


def build_parser() -> argparse.ArgumentParser:
    """Build the CLI argument parser.

    This function is intentionally public to support CLI contract tests.
    """
    parser = argparse.ArgumentParser(
        description="DecisionGraph CLI - Read-only inspection tools",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    # replay command
    replay_parser = subparsers.add_parser(
        "replay", help="Replay events read-only and print digest"
    )
    replay_parser.add_argument("db", help="Path to SQLite database")

    status_parser = subparsers.add_parser(
        "projection-status",
        help="Show projection cursor lag and optional digests",
    )
    status_parser.add_argument("db", help="Path to SQLite database")
    status_parser.add_argument(
        "--include-digests",
        action="store_true",
        help="Include current projection digests in the JSON output",
    )

    # dump-trace command
    dump_parser = subparsers.add_parser("dump-trace", help="Dump trace events as JSON")
    dump_parser.add_argument("db", help="Path to SQLite database")
    dump_parser.add_argument("trace_id", help="Trace ID to dump")
    dump_parser.add_argument(
        "--include-payload",
        action="store_true",
        help="Include payload and extended metadata fields",
    )

    return parser


def _validate_db_path(db_path: str) -> Path:
    """Validate database path for security.

    Args:
        db_path: User-provided database path

    Returns:
        Resolved, validated Path object

    Raises:
        SystemExit: If path is invalid or potentially malicious
    """
    path = Path(db_path)

    # Check for symlink attacks - resolve to canonical path
    try:
        resolved = path.resolve(strict=False)
    except OSError as e:
        print(f"Error: Invalid path '{db_path}': {e}", file=sys.stderr)
        sys.exit(1)

    # Warn if symlink (could point to unexpected location)
    if path.is_symlink():
        print(
            f"Warning: '{db_path}' is a symlink to '{resolved}'",
            file=sys.stderr,
        )

    # Check existence
    if not resolved.exists():
        print(f"Error: Database file '{db_path}' not found", file=sys.stderr)
        sys.exit(1)

    # Check it's a file, not a directory
    if not resolved.is_file():
        print(f"Error: '{db_path}' is not a file", file=sys.stderr)
        sys.exit(1)

    return resolved


def _load_replay_store(events: list[StoredEvent]) -> SQLiteEventStore:
    """Load events into an isolated temporary store for read-only replay."""
    store = SQLiteEventStore(":memory:")
    store.connection.executemany(
        """
        INSERT INTO dg_event_log (
            log_seq, event_id, trace_id, trace_seq, event_type,
            occurred_at, recorded_at,
            producer_id, system, subsystem,
            actor_type, actor_id,
            correlation_id, causation_event_id,
            idempotency_key, schema_version,
            payload_json, payload_hash, tags_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (
                event.log_seq,
                event.event_id,
                event.trace_id,
                event.trace_seq,
                event.event_type,
                event.occurred_at,
                event.recorded_at,
                event.source.producer_id,
                event.source.system,
                event.source.subsystem,
                event.actor.actor_type,
                event.actor.actor_id,
                event.correlation_id,
                event.causation_event_id,
                event.idempotency_key,
                event.schema_version,
                json.dumps(event.payload, sort_keys=True, ensure_ascii=False),
                event.payload_hash,
                json.dumps(event.tags, ensure_ascii=False),
            )
            for event in events
        ],
    )
    store.connection.commit()
    return store


def cmd_replay(db_path: str) -> None:
    """Replay events in isolated temporary state and print digests.

    Args:
        db_path: Path to SQLite database
    """
    validated_path = _validate_db_path(db_path)
    source_store = SQLiteEventStore(str(validated_path), read_only=True)
    replay_store: SQLiteEventStore | None = None
    try:
        replay_store = _load_replay_store(source_store.list_events())
        conn = replay_store.connection
        projector = SQLiteProjector(conn)
        projector.rebuild()
        projector.project_events(replay_store.list_events())

        digests = {
            "context_graph": compute_context_graph_digest(conn),
            "trace_summary": compute_trace_summary_digest(conn),
            "precedent_index": compute_precedent_index_digest(conn),
            "full_projection": compute_full_projection_digest(conn),
        }

        print("Projection digests after replay:")
        for key, value in sorted(digests.items()):
            print(f"  {key}: {value}")
    except Exception as e:
        print(f"Error replaying projections: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        source_store.close()
        if replay_store is not None:
            replay_store.close()


def cmd_dump_trace(db_path: str, trace_id: str, *, include_payload: bool = False) -> None:
    """Dump trace events to stdout.

    Args:
        db_path: Path to SQLite database
        trace_id: Trace ID to dump
    """
    validated_path = _validate_db_path(db_path)

    store = SQLiteEventStore(str(validated_path), read_only=True)

    # Get trace events
    try:
        events = get_trace_events(store, trace_id=trace_id)
    except Exception as e:
        print(f"Error getting trace events: {e}", file=sys.stderr)
        store.close()
        sys.exit(1)

    if not events:
        print(f"No events found for trace_id={trace_id}", file=sys.stderr)
        store.close()
        sys.exit(1)

    # Print events as JSON (safe defaults omit payload and verbose metadata)
    events_data = []
    for event in events:
        event_dict = {
            "log_seq": event.log_seq,
            "event_id": event.event_id,
            "trace_id": event.trace_id,
            "trace_seq": event.trace_seq,
            "event_type": event.event_type,
            "occurred_at": event.occurred_at,
            "recorded_at": event.recorded_at,
        }
        if include_payload:
            event_dict.update(
                {
                    "source": {
                        "producer_id": event.source.producer_id,
                        "system": event.source.system,
                        "subsystem": event.source.subsystem,
                    },
                    "actor": {
                        "actor_type": event.actor.actor_type,
                        "actor_id": event.actor.actor_id,
                    },
                    "correlation_id": event.correlation_id,
                    "causation_event_id": event.causation_event_id,
                    "idempotency_key": event.idempotency_key,
                    "schema_version": event.schema_version,
                    "payload": event.payload,
                    "payload_hash": event.payload_hash,
                    "tags": event.tags,
                }
            )
        events_data.append(event_dict)

    print(json.dumps(events_data, indent=2, sort_keys=True))

    store.close()


def cmd_projection_status(db_path: str, *, include_digests: bool = False) -> None:
    """Print current projection health as deterministic JSON."""
    validated_path = _validate_db_path(db_path)
    store = SQLiteEventStore(str(validated_path), read_only=True)
    try:
        projector = SQLiteProjector(store.connection)
        health = get_projection_health(
            store,
            projector,
            include_digests=include_digests,
        )
        print(json.dumps(asdict(health), indent=2, sort_keys=True))
    except Exception as e:
        print(f"Error getting projection status: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        store.close()


def main() -> None:
    """Main CLI entry point."""
    parser = build_parser()
    args = parser.parse_args()

    if args.command == "replay":
        cmd_replay(args.db)
    elif args.command == "projection-status":
        cmd_projection_status(
            args.db,
            include_digests=args.include_digests,
        )
    elif args.command == "dump-trace":
        cmd_dump_trace(args.db, args.trace_id, include_payload=args.include_payload)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
