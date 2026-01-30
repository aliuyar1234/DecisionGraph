# Demo Output

## Dataset
- Fixtures loaded: 3 (dealdesk, renewal, support)
- Total traces: 3
- Total events: 26
- Context graph nodes: 27
- Context graph edges: 23
- Database: :memory:

## Scenarios
- dealdesk: Deal Desk healthcare extra 10% discount with tribal knowledge made explicit
- renewal: Renewal Agent with 20% discount exception and Finance approval
- support: Support Escalation with cross-system synthesis to Tier 3

## Sample Trace
- Scenario: renewal
- Trace ID: aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
- Event count: 9
- First event: TraceStarted
- Last event: TraceFinished
- Primary entity: account sf:acct:001 (salesforce)

## Context Subgraph
- Center: entity account:sf:acct:001
- Nodes: 2
- Edges: 2
- Truncated: False

## Precedent Query
- Hits: 1
- Top hit: aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa (renewal_discount, success)

## Projection Digests
- context_graph: sha256:866b7d3b199949aa92f452840151973ef56387329f00fa4b25f438c636959528
- full_projection: sha256:045813620d5a47e7096eccc53d86d1e484db12bb257e4610536fb97b10d783ec
- precedent_index: sha256:ac214e9522f666636be86f7cf9d86d169c6febc7e68acb38af76ad84785d6be6
- trace_summary: sha256:f985a505c80d3aa7a327c29b264160da1745c712d642e0dfe1b4fe79d29f4ea5
