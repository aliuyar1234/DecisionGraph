"""DecisionGraph - Append-only decision trace library for AI agents."""

__version__ = "0.1.0"

from decisiongraph.api import DecisionGraph
from decisiongraph.domain.events import (
    ALL_EVENT_TYPES,
    EVENT_TYPE_ACTION_COMMITTED,
    EVENT_TYPE_ACTION_PROPOSED,
    EVENT_TYPE_APPROVAL_RECORDED,
    EVENT_TYPE_ENTITY_OBSERVED,
    EVENT_TYPE_EXCEPTION_REQUESTED,
    EVENT_TYPE_INPUT_OBSERVED,
    EVENT_TYPE_POLICY_EVALUATED,
    EVENT_TYPE_PRECEDENT_CITED,
    EVENT_TYPE_TRACE_FINISHED,
    EVENT_TYPE_TRACE_STARTED,
)
from decisiongraph.errors import DecisionGraphError

__all__ = [
    "__version__",
    "DecisionGraph",
    "DecisionGraphError",
    # Event type constants
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
