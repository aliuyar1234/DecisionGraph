"""Property/fuzz-style invariant tests for serialization, validation, and graph queries."""

from __future__ import annotations

import random
import string
from typing import Any

import pytest

from decisiongraph.domain.events import (
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_TRACE_STARTED,
)
from decisiongraph.domain.validation import FORBIDDEN_SUBSTRINGS, check_pii_guard
from decisiongraph.errors import DG_ERR_PII_POLICY_VIOLATION, DecisionGraphError
from decisiongraph.ids import generate_trace_id
from decisiongraph.projections.projector import SQLiteProjector
from decisiongraph.query import NodeRef, get_context_subgraph
from decisiongraph.query.filters import GraphFilter
from decisiongraph.serialization import compute_payload_hash
from decisiongraph.storage.sqlite import SQLiteEventStore
from decisiongraph.testing import create_test_envelope


def _rand_key(rng: random.Random) -> str:
    alphabet = string.ascii_lowercase
    return "".join(rng.choice(alphabet) for _ in range(rng.randint(1, 8)))


def _rand_scalar(rng: random.Random) -> str | int | bool | None:
    kind = rng.choice(["str", "int", "bool", "none"])
    if kind == "str":
        return "".join(rng.choice(string.ascii_letters) for _ in range(rng.randint(0, 16)))
    if kind == "int":
        return rng.randint(-10_000, 10_000)
    if kind == "bool":
        return bool(rng.getrandbits(1))
    return None


def _rand_json_value(rng: random.Random, depth: int = 0) -> Any:
    if depth >= 4:
        return _rand_scalar(rng)

    kind = rng.choice(["scalar", "list", "dict"])
    if kind == "scalar":
        return _rand_scalar(rng)
    if kind == "list":
        return [_rand_json_value(rng, depth + 1) for _ in range(rng.randint(0, 5))]

    result: dict[str, Any] = {}
    for _ in range(rng.randint(0, 6)):
        result[_rand_key(rng)] = _rand_json_value(rng, depth + 1)
    return result


def _permute_keys(value: Any, rng: random.Random) -> Any:
    if isinstance(value, dict):
        items = list(value.items())
        rng.shuffle(items)
        return {key: _permute_keys(inner, rng) for key, inner in items}
    if isinstance(value, list):
        return [_permute_keys(item, rng) for item in value]
    return value


def _randomize_case(pattern: str, rng: random.Random) -> str:
    chars: list[str] = []
    for char in pattern:
        if char.isalpha():
            chars.append(char.upper() if rng.random() < 0.5 else char.lower())
        else:
            chars.append(char)
    return "".join(chars)


class TestSerializationProperties:
    """Property/fuzz checks for canonical hashing invariants."""

    def test_payload_hash_invariant_under_key_permutations(self) -> None:
        rng = random.Random(20260224)
        for _ in range(250):
            payload = {"root": _rand_json_value(rng)}
            permuted_payload = _permute_keys(payload, rng)
            assert compute_payload_hash(payload) == compute_payload_hash(permuted_payload)


class TestValidationProperties:
    """Property/fuzz checks for validation boundaries."""

    def test_pii_guard_detects_randomized_case_variants(self) -> None:
        rng = random.Random(20260225)
        for forbidden in sorted(FORBIDDEN_SUBSTRINGS):
            variant = _randomize_case(forbidden, rng)
            data = {"payload": f"prefix-{variant}-suffix"}
            with pytest.raises(DecisionGraphError) as exc_info:
                check_pii_guard(data)
            assert exc_info.value.code == DG_ERR_PII_POLICY_VIOLATION


class TestGraphTraversalProperties:
    """Property/fuzz checks for graph traversal invariants."""

    def test_context_subgraph_invariants_hold_across_random_filters(self) -> None:
        rng = random.Random(20260226)
        with SQLiteEventStore(":memory:") as store:
            projector = SQLiteProjector(store.connection)
            trace_id = generate_trace_id()

            start = create_test_envelope(
                trace_id=trace_id,
                trace_seq=0,
                event_type=EVENT_TYPE_TRACE_STARTED,
                payload={
                    "workflow": "graph-fuzz",
                    "title": "graph-fuzz",
                    "primary_entity": {"entity_type": "account", "entity_id": "acct-0"},
                },
            )
            store.append_event(start)

            for seq in range(1, 81):
                env = create_test_envelope(
                    trace_id=trace_id,
                    trace_seq=seq,
                    event_type=EVENT_TYPE_ENTITY_OBSERVED,
                    payload={
                        "entity": {
                            "entity_type": "account",
                            "entity_id": f"acct-{rng.randint(0, 40)}",
                        },
                        "role": "related",
                        "facts": [],
                    },
                    idempotency_key=f"fuzz:{seq}",
                )
                store.append_event(env)

            projector.rebuild()
            projector.project_events(store.list_events())

            center = NodeRef(node_type="trace", node_id=trace_id)
            for _ in range(50):
                filter_opts = GraphFilter(
                    max_depth=rng.randint(0, 3),
                    max_nodes=rng.randint(5, 200),
                    max_edges=rng.randint(5, 300),
                )
                subgraph_a = get_context_subgraph(
                    store, projector, center, filter_opts=filter_opts
                )
                subgraph_b = get_context_subgraph(
                    store, projector, center, filter_opts=filter_opts
                )

                node_ids_a = [node.node_id for node in subgraph_a.nodes]
                edge_ids_a = [edge.edge_id for edge in subgraph_a.edges]
                node_ids_b = [node.node_id for node in subgraph_b.nodes]
                edge_ids_b = [edge.edge_id for edge in subgraph_b.edges]

                assert node_ids_a == node_ids_b
                assert edge_ids_a == edge_ids_b
                assert node_ids_a == sorted(node_ids_a)
                assert edge_ids_a == sorted(edge_ids_a)
                assert len(node_ids_a) == len(set(node_ids_a))
                assert len(edge_ids_a) == len(set(edge_ids_a))
