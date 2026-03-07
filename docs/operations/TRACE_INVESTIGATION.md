# Trace Investigation

## Purpose

This runbook explains how operators should investigate a trace in the Phase 6 console.

## Recommended Flow

1. open the console and confirm tenant, environment, and projection posture in the hero and health cards
2. choose a trace from the recent-trace rail
3. inspect the trace summary for workflow, outcome, event count, and primary entity
4. open payload inspection on the key events in the timeline
5. review the policy and exception cards to understand decision basis and human intervention
6. compare precedents if the case needs historical context
7. copy the investigator handoff block into incident notes or escalation threads

## What To Look For

- `PolicyEvaluated` for policy lineage and reasoning
- `ExceptionRequested` for exception identifiers and rationale
- `ApprovalRecorded` for who approved and why
- `ActionProposed` and `ActionCommitted` for downstream business impact
- `TraceFinished` when present for outcome closure

## When To Escalate

Escalate when:

- the health dashboard shows stale projections or open failures
- the trace shows an exception without an approval
- precedent outcomes diverge in a way that is not explained by policy lineage
- replay alignment suggests current digests do not match the latest completed recovery run
