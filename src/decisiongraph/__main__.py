"""DecisionGraph CLI - Read-only inspection tools per SSOT P6.

Usage:
    python -m decisiongraph replay <db>
    python -m decisiongraph dump-trace <db> <trace_id> [--include-payload]

All CLI operations are read-only and do not modify the database.
"""

import argparse
import json
import sys
from pathlib import Path

from decisiongraph.projections.digests import (
    compute_context_graph_digest,
    compute_full_projection_digest,
    compute_precedent_index_digest,
    compute_trace_summary_digest,
)
from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.query import get_trace_events
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
        "replay", help="Rebuild projections and print digest"
    )
    replay_parser.add_argument("db", help="Path to SQLite database")

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


def cmd_replay(db_path: str) -> None:
    """Rebuild projections and print digest.

    Args:
        db_path: Path to SQLite database
    """
    validated_path = _validate_db_path(db_path)

    # Open database - replay modifies projections but not events
    store = SQLiteEventStore(str(validated_path))
    conn = store.connection
    projector = SQLiteProjector(conn)

    # Rebuild projections
    projector.rebuild()
    all_events = store.list_events()
    projector.project_events(all_events)

    # Compute and print digests
    digests = {
        "context_graph": compute_context_graph_digest(conn),
        "trace_summary": compute_trace_summary_digest(conn),
        "precedent_index": compute_precedent_index_digest(conn),
        "full_projection": compute_full_projection_digest(conn),
    }

    print("Projection digests after replay:")
    for key, value in sorted(digests.items()):
        print(f"  {key}: {value}")

    store.close()


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


def main() -> None:
    """Main CLI entry point."""
    parser = build_parser()
    args = parser.parse_args()

    if args.command == "replay":
        cmd_replay(args.db)
    elif args.command == "dump-trace":
        cmd_dump_trace(args.db, args.trace_id, include_payload=args.include_payload)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
