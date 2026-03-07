# Demo Output

## Dataset
- Fixtures loaded: 5 (dealdesk, release_rejected, renewal, support, sync_failure)
- Total traces: 5
- Total events: 40
- Context graph nodes: 40
- Context graph edges: 36
- Database: :memory:

## Scenarios
- dealdesk: Deal Desk healthcare extra 10% discount with tribal knowledge made explicit
- release_rejected: High-risk payout release rejected during manual review
- renewal: Renewal Agent with 20% discount exception and Finance approval
- support: Support Escalation with cross-system synthesis to Tier 3
- sync_failure: CRM to billing sync fails after the downstream commit attempt

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
- context_graph: sha256:57870a0d6ef5f07dbf79eb53c642987582f102f05bc06de3d94d709ea43c57b1
- full_projection: sha256:e912b7080ed689e1031e963c1cb33ca3acd752952876d5f446c12329f2673614
- precedent_index: sha256:a87cf8124584225fd87e80cbd573dc40af912e4c92b48621928edec9dadc9251
- trace_summary: sha256:5c5d5c3bfb68b74818e1f5c742522154c5ab0711b09c0cdea8eb02a110b391dd
