# Research: E2E Integration & Documentation

**Date**: 2026-01-01
**Phase**: P6 — E2E Fixtures + Documentation + Optional CLI

## Overview

All technical decisions and scenarios are defined in SSOT Section 10. This document consolidates the requirements.

## Scenario A: Renewal Agent (SSOT 10.1)

### Context
- Renewal agent requests 20% discount for Acme Corp
- Policy cap is 10%
- Requires exception route with Finance approval

### Event Sequence (9 events)

1. **TraceStarted** (trace_seq=0)
   - workflow: "renewal_discount"
   - title: "20% discount for Acme Corp renewal"
   - primary_entity: Account:ACC-ACME

2. **EntityObserved** (trace_seq=1)
   - entity: Account:ACC-ACME
   - role: "primary"
   - facts: [ARR: $50,000, tier: "enterprise"]

3. **InputObserved** (trace_seq=2)
   - input_id: "sf_renewal_data"
   - facts: [requested_discount: "20%", renewal_date: "2025-03-01"]

4. **PolicyEvaluated** (trace_seq=3)
   - policy: renewal_discount_cap:3.2
   - decision: "require_exception"
   - violations: ["discount_exceeds_cap"]

5. **PrecedentCited** (trace_seq=4)
   - cited_trace_id: <previous trace>
   - reason: "Similar Acme renewal approved 6 months ago"

6. **ExceptionRequested** (trace_seq=5)
   - exception_id: "EXC-001"
   - policy: renewal_discount_cap:3.2
   - reason: "Strategic account, high LTV"

7. **ApprovalRecorded** (trace_seq=6)
   - approval_id: "APR-001"
   - subject: exception:EXC-001
   - approver: person:jane.doe@acme.com
   - decision: "approved"

8. **ActionCommitted** (trace_seq=7)
   - action_id: "ACT-001"
   - status: "success"
   - external_reference: "OPP-123456"

9. **TraceFinished** (trace_seq=8)
   - outcome: "success"
   - summary: "20% discount approved via exception"

## Scenario B: Support Escalation (SSOT 10.2)

### Context
- Cross-system synthesis for Tier 3 escalation
- ARR from CRM, escalations from Zendesk, churn-risk flag

### Key Elements
- EntityObserved for Account with ARR
- Multiple InputObserved (Zendesk tickets, Salesforce data)
- PolicyEvaluated for escalation rules
- ActionCommitted: Escalate to Tier 3

## Scenario C: Deal Desk (SSOT 10.3)

### Context
- Healthcare extra discount (tribal knowledge made explicit)
- Exception with PrecedentCited

### Key Elements
- PolicyEvaluated for standard discount
- PrecedentCited for healthcare precedent
- ExceptionRequested citing tribal knowledge
- ApprovalRecorded from deal desk

## Golden Fixture Format

```json
{
  "scenario": "renewal",
  "ssot_reference": "10.1",
  "description": "Renewal Agent with 20% discount exception",
  "events": [
    {
      "event_id": "...",
      "trace_id": "...",
      "trace_seq": 0,
      "event_type": "TraceStarted",
      "occurred_at": "2025-12-31T10:00:00Z",
      "source": {...},
      "actor": {...},
      "idempotency_key": "...",
      "schema_version": 1,
      "payload": {...}
    }
  ],
  "expected_digests": {
    "context_graph": "sha256:...",
    "precedent_index": "sha256:..."
  }
}
```

## CLI Commands (Optional, P3)

### replay

```bash
python -m decisiongraph replay decisiongraph.db
```

Output:
```
Replaying 100 events...
Context Graph Digest: sha256:abc123...
Precedent Index Digest: sha256:def456...
```

### dump-trace

```bash
python -m decisiongraph dump-trace decisiongraph.db b3b0a4a8-...
```

Output:
```
Trace: b3b0a4a8-2a2f-4bdf-b9ce-6a4bbf3aa2c4
Workflow: renewal_discount
Title: 20% discount for Acme Corp renewal

Events:
  0: TraceStarted
  1: EntityObserved
  2: InputObserved
  ...
```

## PII/Chain-of-Thought Guard

Fixtures MUST NOT contain:
- "Bearer " tokens
- "xoxb-" Slack tokens
- "-----BEGIN" private keys
- Chain-of-thought reasoning dumps
- Full Slack/Chat logs

Only structured, redacted excerpts allowed.

## Documentation Requirements

### README.md

```markdown
# DecisionGraph

System-of-Record for enterprise decisions.

## Installation

pip install decisiongraph

## Quick Start

from decisiongraph import DecisionGraph

dg = DecisionGraph("decisions.db")

# Start a trace
trace_id = dg.start_trace(...)

# Emit events
dg.observe_entity(trace_id, ...)

# Finish trace
dg.finish_trace(trace_id, ...)

## License

Apache-2.0
```

## Conclusion

All scenarios and fixture formats are specified in SSOT. No external research required.
