"""Testing utilities for DecisionGraph.

Provides InMemoryEventStore for unit tests and golden fixture utilities.
"""

from decisiongraph.testing.fakes import InMemoryEventStore, create_test_envelope

__all__ = [
    "InMemoryEventStore",
    "create_test_envelope",
]
