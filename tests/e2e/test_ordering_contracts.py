"""Deterministic ordering contracts for query endpoints and CLI JSON modes."""

from __future__ import annotations

import json
from io import StringIO
from pathlib import Path
from unittest.mock import patch

import pytest

from decisiongraph.__main__ import cmd_dump_trace, cmd_projection_status, cmd_replay
from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.query import (
    NodeRef,
    PrecedentQuery,
    find_precedents,
    get_context_subgraph,
    get_trace_events,
    get_trace_summary,
    list_events,
    list_node_edges,
)
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.testing.golden import GoldenFixture, load_all_fixtures

FIXTURES_DIR = Path(__file__).parent.parent / "golden"


@pytest.fixture
def populated_db(tmp_path: Path) -> tuple[str, SQLiteEventStore, SQLiteProjector, GoldenFixture]:
    db_path = tmp_path / "ordering-contracts.db"
    store = SQLiteEventStore(str(db_path))
    projector = SQLiteProjector(store.connection)

    fixtures = load_all_fixtures(FIXTURES_DIR)
    for fixture in fixtures:
        for envelope in fixture.events:
            store.append_event(envelope)

    projector.rebuild()
    projector.project_events(store.list_events())

    renewal = next(fixture for fixture in fixtures if fixture.scenario == "renewal")
    yield str(db_path), store, projector, renewal
    store.close()


class TestQueryOrderingContracts:
    """Query endpoint ordering should be deterministic and stable."""

    def test_all_query_endpoints_are_deterministic(
        self, populated_db: tuple[str, SQLiteEventStore, SQLiteProjector, GoldenFixture]
    ) -> None:
        _, store, projector, renewal = populated_db
        trace_id = renewal.trace_id

        listed_a = list_events(store)
        listed_b = list_events(store)
        assert [event.log_seq for event in listed_a] == [event.log_seq for event in listed_b]
        assert [event.log_seq for event in listed_a] == sorted(
            event.log_seq for event in listed_a
        )

        trace_events_a = get_trace_events(store, trace_id=trace_id)
        trace_events_b = get_trace_events(store, trace_id=trace_id)
        assert [event.event_id for event in trace_events_a] == [
            event.event_id for event in trace_events_b
        ]
        assert [event.trace_seq for event in trace_events_a] == sorted(
            event.trace_seq for event in trace_events_a
        )

        summary_a = get_trace_summary(store, projector, trace_id=trace_id)
        summary_b = get_trace_summary(store, projector, trace_id=trace_id)
        assert summary_a == summary_b

        center = NodeRef(node_type="trace", node_id=trace_id)
        subgraph_a = get_context_subgraph(store, projector, center, max_depth=2)
        subgraph_b = get_context_subgraph(store, projector, center, max_depth=2)
        node_ids_a = [node.node_id for node in subgraph_a.nodes]
        edge_ids_a = [edge.edge_id for edge in subgraph_a.edges]
        assert node_ids_a == [node.node_id for node in subgraph_b.nodes]
        assert edge_ids_a == [edge.edge_id for edge in subgraph_b.edges]
        assert node_ids_a == sorted(node_ids_a)
        assert edge_ids_a == sorted(edge_ids_a)

        page_a = list_node_edges(store, projector, center, direction="both", limit=3)
        page_b = list_node_edges(store, projector, center, direction="both", limit=3)
        assert [edge.edge_id for edge in page_a.edges] == [edge.edge_id for edge in page_b.edges]
        assert [
            (edge.log_seq, edge.edge_id) for edge in page_a.edges
        ] == sorted((edge.log_seq, edge.edge_id) for edge in page_a.edges)

        precedents_a = find_precedents(
            store,
            projector,
            PrecedentQuery(policy_id="discount_cap", outcome="success", limit=10),
        )
        precedents_b = find_precedents(
            store,
            projector,
            PrecedentQuery(policy_id="discount_cap", outcome="success", limit=10),
        )
        hits_a = [(hit.trace_id, hit.finished_at) for hit in precedents_a]
        hits_b = [(hit.trace_id, hit.finished_at) for hit in precedents_b]
        assert hits_a == hits_b


class TestCliOrderingContracts:
    """CLI JSON output modes should remain deterministic."""

    def test_dump_trace_default_and_include_payload_modes_are_stable(
        self, populated_db: tuple[str, SQLiteEventStore, SQLiteProjector, GoldenFixture]
    ) -> None:
        db_path, _, _, renewal = populated_db

        with patch("sys.stdout", new_callable=StringIO) as stdout_default_a:
            cmd_dump_trace(db_path, renewal.trace_id, include_payload=False)
        with patch("sys.stdout", new_callable=StringIO) as stdout_default_b:
            cmd_dump_trace(db_path, renewal.trace_id, include_payload=False)
        default_a = stdout_default_a.getvalue()
        default_b = stdout_default_b.getvalue()
        assert default_a == default_b

        with patch("sys.stdout", new_callable=StringIO) as stdout_payload_a:
            cmd_dump_trace(db_path, renewal.trace_id, include_payload=True)
        with patch("sys.stdout", new_callable=StringIO) as stdout_payload_b:
            cmd_dump_trace(db_path, renewal.trace_id, include_payload=True)
        payload_a = stdout_payload_a.getvalue()
        payload_b = stdout_payload_b.getvalue()
        assert payload_a == payload_b

        default_events = json.loads(default_a)
        payload_events = json.loads(payload_a)
        assert [event["trace_seq"] for event in default_events] == sorted(
            event["trace_seq"] for event in default_events
        )
        assert [event["trace_seq"] for event in payload_events] == sorted(
            event["trace_seq"] for event in payload_events
        )

        for event in default_events:
            assert list(event.keys()) == sorted(event.keys())
            assert "payload" not in event
            assert "source" not in event
            assert "actor" not in event

        for event in payload_events:
            assert list(event.keys()) == sorted(event.keys())
            assert "payload" in event
            assert "source" in event
            assert "actor" in event

    def test_replay_output_is_stable(
        self, populated_db: tuple[str, SQLiteEventStore, SQLiteProjector, GoldenFixture]
    ) -> None:
        db_path, _, _, _ = populated_db

        with patch("sys.stdout", new_callable=StringIO) as stdout_a:
            cmd_replay(db_path)
        with patch("sys.stdout", new_callable=StringIO) as stdout_b:
            cmd_replay(db_path)

        assert stdout_a.getvalue() == stdout_b.getvalue()

    def test_projection_status_output_is_stable(
        self, populated_db: tuple[str, SQLiteEventStore, SQLiteProjector, GoldenFixture]
    ) -> None:
        db_path, _, _, _ = populated_db

        with patch("sys.stdout", new_callable=StringIO) as stdout_a:
            cmd_projection_status(db_path, include_digests=True)
        with patch("sys.stdout", new_callable=StringIO) as stdout_b:
            cmd_projection_status(db_path, include_digests=True)

        output_a = stdout_a.getvalue()
        output_b = stdout_b.getvalue()
        assert output_a == output_b

        payload = json.loads(output_a)
        assert list(payload.keys()) == sorted(payload.keys())
        assert list(payload["digests"].keys()) == sorted(payload["digests"].keys())
