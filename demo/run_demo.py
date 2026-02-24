"""Generate a deterministic demo report from golden fixtures."""

from __future__ import annotations

import argparse
from pathlib import Path

from decisiongraph.projections.digests import (
    compute_context_graph_digest,
    compute_full_projection_digest,
    compute_precedent_index_digest,
    compute_trace_summary_digest,
)
from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.query import (
    NodeRef,
    PrecedentQuery,
    find_precedents,
    get_context_subgraph,
    get_trace_events,
)
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.testing.golden import GoldenFixture, load_fixture

DEMO_ROOT = Path(__file__).resolve().parent
REPO_ROOT = DEMO_ROOT.parent


def resolve_demo_path(path: Path, label: str) -> Path:
    """Resolve demo paths and prevent writes outside repository root."""
    resolved = path.expanduser().resolve()
    try:
        resolved.relative_to(REPO_ROOT)
    except ValueError as exc:
        raise SystemExit(
            f"{label} path must be inside '{REPO_ROOT}', got '{resolved}'"
        ) from exc
    return resolved


def load_fixtures(fixtures_dir: Path) -> list[GoldenFixture]:
    if not fixtures_dir.exists():
        raise SystemExit(f"Fixtures directory not found: {fixtures_dir}")

    fixtures: list[GoldenFixture] = []
    for fixture_dir in sorted(fixtures_dir.iterdir()):
        if (fixture_dir / "events.json").exists():
            fixtures.append(load_fixture(fixture_dir))

    if not fixtures:
        raise SystemExit(f"No fixtures found in {fixtures_dir}")

    return fixtures


def build_db(db_path: str, fixtures: list[GoldenFixture]) -> SQLiteEventStore:
    store = SQLiteEventStore(db_path)
    projector = SQLiteProjector(store.connection)

    for fixture in fixtures:
        for envelope in fixture.events:
            store.append_event(envelope)

    projector.rebuild()
    projector.project_events(store.list_events())
    return store


def count_rows(conn, table_name: str) -> int:
    row = conn.execute(f"SELECT COUNT(*) AS count FROM {table_name}").fetchone()
    return int(row["count"]) if row else 0


def count_distinct_traces(conn) -> int:
    row = conn.execute(
        "SELECT COUNT(DISTINCT trace_id) AS count FROM dg_event_log"
    ).fetchone()
    return int(row["count"]) if row else 0


def select_fixture(fixtures: list[GoldenFixture]) -> GoldenFixture:
    for fixture in fixtures:
        if fixture.scenario == "renewal":
            return fixture
    return fixtures[0]


def extract_primary_entity(events) -> dict[str, str] | None:
    for event in events:
        if event.event_type == "TraceStarted":
            primary_entity = event.payload.get("primary_entity")
            if primary_entity:
                return primary_entity
    return None


def extract_policy(events) -> dict[str, str] | None:
    for event in events:
        if event.event_type == "PolicyEvaluated":
            policy = event.payload.get("policy")
            if policy:
                return policy
    return None


def extract_outcome(events) -> str | None:
    for event in reversed(events):
        if event.event_type == "TraceFinished":
            return event.payload.get("outcome")
    return None


def render_output(
    fixtures: list[GoldenFixture],
    selected: GoldenFixture,
    events,
    primary_entity,
    precedents,
    subgraph,
    digests: dict[str, str],
    total_events: int,
    total_traces: int,
    total_nodes: int,
    total_edges: int,
    db_label: str,
) -> str:
    scenario_lines = [
        f"- {fixture.scenario}: {fixture.description}" for fixture in fixtures
    ]
    scenarios = ", ".join(fixture.scenario for fixture in fixtures)
    first_event = events[0].event_type if events else "n/a"
    last_event = events[-1].event_type if events else "n/a"

    if primary_entity:
        primary_text = (
            f"{primary_entity.get('entity_type')} "
            f"{primary_entity.get('entity_id')} "
            f"({primary_entity.get('system')})"
        )
    else:
        primary_text = "not found"

    center_text = "n/a"
    if primary_entity:
        center_text = (
            f"{primary_entity.get('entity_type', 'unknown')}:"
            f"{primary_entity.get('entity_id', 'unknown')}"
        )

    precedent_summary = "none"
    if precedents:
        top_hit = precedents[0]
        precedent_summary = (
            f"{top_hit.trace_id} ({top_hit.workflow}, {top_hit.outcome})"
        )

    lines = [
        "# Demo Output",
        "",
        "## Dataset",
        f"- Fixtures loaded: {len(fixtures)} ({scenarios})",
        f"- Total traces: {total_traces}",
        f"- Total events: {total_events}",
        f"- Context graph nodes: {total_nodes}",
        f"- Context graph edges: {total_edges}",
        f"- Database: {db_label}",
        "",
        "## Scenarios",
        *scenario_lines,
        "",
        "## Sample Trace",
        f"- Scenario: {selected.scenario}",
        f"- Trace ID: {selected.trace_id}",
        f"- Event count: {len(events)}",
        f"- First event: {first_event}",
        f"- Last event: {last_event}",
        f"- Primary entity: {primary_text}",
        "",
        "## Context Subgraph",
        f"- Center: entity {center_text}",
        f"- Nodes: {len(subgraph.nodes) if subgraph else 0}",
        f"- Edges: {len(subgraph.edges) if subgraph else 0}",
        f"- Truncated: {subgraph.truncated if subgraph else 'n/a'}",
        "",
        "## Precedent Query",
        f"- Hits: {len(precedents)}",
        f"- Top hit: {precedent_summary}",
        "",
        "## Projection Digests",
    ]

    for key in sorted(digests):
        lines.append(f"- {key}: {digests[key]}")

    lines.append("")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate DecisionGraph demo output")
    parser.add_argument(
        "--fixtures",
        type=Path,
        default=Path("tests") / "golden",
        help="Path to golden fixtures directory",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("demo") / "output.md",
        help="Output markdown path",
    )
    parser.add_argument(
        "--db",
        type=Path,
        default=None,
        help="Optional SQLite DB path (defaults to in-memory)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite output database if it exists",
    )

    args = parser.parse_args()
    fixtures = load_fixtures(args.fixtures)
    output_path = resolve_demo_path(args.output, "Output")

    db_label = ":memory:"
    db_path = ":memory:"
    if args.db is not None:
        db_file = resolve_demo_path(args.db, "Database")
        db_label = str(db_file)
        db_path = str(db_file)
        if db_file.exists():
            if not args.force:
                raise SystemExit(f"Output DB exists: {db_file} (use --force)")
            db_file.unlink()
        db_file.parent.mkdir(parents=True, exist_ok=True)

    store = build_db(db_path, fixtures)
    projector = SQLiteProjector(store.connection)

    selected = select_fixture(fixtures)
    events = get_trace_events(store, trace_id=selected.trace_id)
    primary_entity = extract_primary_entity(events)

    subgraph = None
    if primary_entity:
        entity_type = primary_entity.get("entity_type", "unknown")
        entity_id = primary_entity.get("entity_id", "unknown")
        center = NodeRef(node_type="entity", node_id=f"{entity_type}:{entity_id}")
        subgraph = get_context_subgraph(store, projector, center, max_depth=1)

    policy = extract_policy(events)
    outcome = extract_outcome(events)
    precedents = []
    policy_id = policy.get("policy_id") if policy else None
    policy_version = policy.get("policy_version") if policy else None
    if policy_id:
        query = PrecedentQuery(
            policy_id=policy_id,
            policy_version=policy_version,
            outcome=outcome,
            limit=5,
        )
        precedents = find_precedents(store, projector, query)

    conn = store.connection
    total_events = count_rows(conn, "dg_event_log")
    total_traces = count_distinct_traces(conn)
    total_nodes = count_rows(conn, "dg_cg_nodes")
    total_edges = count_rows(conn, "dg_cg_edges")

    digests = {
        "context_graph": compute_context_graph_digest(conn),
        "trace_summary": compute_trace_summary_digest(conn),
        "precedent_index": compute_precedent_index_digest(conn),
        "full_projection": compute_full_projection_digest(conn),
    }

    output = render_output(
        fixtures=fixtures,
        selected=selected,
        events=events,
        primary_entity=primary_entity,
        precedents=precedents,
        subgraph=subgraph,
        digests=digests,
        total_events=total_events,
        total_traces=total_traces,
        total_nodes=total_nodes,
        total_edges=total_edges,
        db_label=db_label,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(output, encoding="utf-8")
    print(output)

    store.close()


if __name__ == "__main__":
    main()
