"""Public API/CLI compatibility tests for v1 contract stability."""

from __future__ import annotations

import argparse
import inspect

import decisiongraph
from decisiongraph.__main__ import build_parser
from decisiongraph.api import DecisionGraph

EXPECTED_TOP_LEVEL_EXPORTS = [
    "__version__",
    "DecisionGraph",
    "DecisionGraphError",
    "EVENT_TYPE_TRACE_STARTED",
    "EVENT_TYPE_INPUT_OBSERVED",
    "EVENT_TYPE_ENTITY_OBSERVED",
    "EVENT_TYPE_POLICY_EVALUATED",
    "EVENT_TYPE_EXCEPTION_REQUESTED",
    "EVENT_TYPE_APPROVAL_RECORDED",
    "EVENT_TYPE_PRECEDENT_CITED",
    "EVENT_TYPE_ACTION_PROPOSED",
    "EVENT_TYPE_ACTION_COMMITTED",
    "EVENT_TYPE_TRACE_FINISHED",
    "ALL_EVENT_TYPES",
]

EXPECTED_DECISIONGRAPH_METHOD_PARAMS: dict[str, list[str]] = {
    "from_postgres": ["cls", "conninfo"],
    "close": ["self"],
    "append_event": [
        "self",
        "trace_id",
        "event_type",
        "payload",
        "source",
        "actor",
        "idempotency_key",
        "correlation_id",
        "causation_event_id",
        "schema_version",
        "tags",
        "occurred_at",
    ],
    "start_trace": [
        "self",
        "workflow",
        "title",
        "primary_entity",
        "source",
        "actor",
        "context",
        "trace_id",
    ],
    "finish_trace": [
        "self",
        "trace_id",
        "outcome",
        "source",
        "actor",
        "summary",
    ],
    "get_trace_events": ["self", "trace_id"],
    "get_context_subgraph": ["self", "node_type", "node_id", "max_depth"],
    "find_precedents": [
        "self",
        "policy_id",
        "policy_version",
        "entity_type",
        "entity_id",
        "outcome",
        "limit",
    ],
    "is_trace_finished": ["self", "trace_id"],
    "sync_projections": ["self", "batch_size"],
    "replay_projections": ["self", "batch_size"],
}


def _extract_subparsers_action(parser: argparse.ArgumentParser) -> argparse._SubParsersAction:
    for action in parser._actions:
        if isinstance(action, argparse._SubParsersAction):
            return action
    raise AssertionError("CLI parser has no subparsers action")


def _public_method_param_names(attr_name: str) -> list[str]:
    member = DecisionGraph.__dict__[attr_name]
    function = member.__func__ if isinstance(member, classmethod) else member
    signature = inspect.signature(function)
    return list(signature.parameters.keys())


def test_top_level_exports_contract() -> None:
    """Public `decisiongraph` exports are contract-frozen for v1."""
    assert decisiongraph.__all__ == EXPECTED_TOP_LEVEL_EXPORTS
    for attr in EXPECTED_TOP_LEVEL_EXPORTS:
        assert hasattr(decisiongraph, attr)


def test_decisiongraph_public_method_signature_contract() -> None:
    """Public `DecisionGraph` method names + parameter order are v1-frozen."""
    actual_public_methods = {
        name
        for name, member in DecisionGraph.__dict__.items()
        if (
            (inspect.isfunction(member) or isinstance(member, classmethod))
            and not name.startswith("_")
        )
    }
    assert actual_public_methods == set(EXPECTED_DECISIONGRAPH_METHOD_PARAMS)

    for method_name, expected_params in EXPECTED_DECISIONGRAPH_METHOD_PARAMS.items():
        assert _public_method_param_names(method_name) == expected_params


def test_cli_command_and_flag_contract() -> None:
    """CLI commands/flags are contract-frozen for v1 compatibility."""
    parser = build_parser()
    subparsers = _extract_subparsers_action(parser).choices

    assert set(subparsers) == {"replay", "dump-trace"}

    replay = subparsers["replay"]
    replay_positionals = [
        action.dest
        for action in replay._actions
        if not action.option_strings and action.dest != "help"
    ]
    assert replay_positionals == ["db"]

    dump_trace = subparsers["dump-trace"]
    dump_positionals = [
        action.dest
        for action in dump_trace._actions
        if not action.option_strings and action.dest != "help"
    ]
    assert dump_positionals == ["db", "trace_id"]

    dump_flags = {
        option
        for action in dump_trace._actions
        for option in action.option_strings
    }
    assert "--include-payload" in dump_flags
