# Quickstart

## Install

```bash
git clone https://github.com/aliuyar1234/DecisionGraph.git
cd DecisionGraph
uv sync
```

## Record a trace

```python
from decisiongraph import DecisionGraph
from decisiongraph.domain.types import ActorRef, EntityRef, SourceRef

dg = DecisionGraph(":memory:")
source = SourceRef(producer_id="demo", system="local")
actor = ActorRef(actor_type="agent", actor_id="demo-agent")
entity = EntityRef(entity_type="account", entity_id="acct-123", system="crm")

trace_id = dg.start_trace(
    workflow="discount_review",
    title="Discount review for acct-123",
    primary_entity=entity,
    source=source,
    actor=actor,
)

dg.finish_trace(trace_id, outcome="success", source=source, actor=actor)
```

## Replay and verify

```bash
python -m decisiongraph replay sample.db
```
