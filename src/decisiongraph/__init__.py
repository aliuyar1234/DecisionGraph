"""DecisionGraph - Append-only decision trace library for AI agents."""

__version__ = "0.1.0"

from decisiongraph.api import DecisionGraph
from decisiongraph.errors import DecisionGraphError

__all__ = [
    "__version__",
    "DecisionGraph",
    "DecisionGraphError",
]
