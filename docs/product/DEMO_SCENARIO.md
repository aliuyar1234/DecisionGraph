# Demo Scenario

## Title

Enterprise Revenue Exception Control Plane

## Purpose

This is the first serious self-hosted release demo that the current BEAM platform already supports end to end.

The goal is to prove that DecisionGraph is not just storing traces. It actively runs the decision operations loop for a high-stakes workflow with precedent context, workflow escalation, operator investigation, and replay verification.

## Scenario Summary

An AI-assisted revenue operations system is handling a large enterprise renewal.

The agent proposes a discount that exceeds the standard policy cap.

DecisionGraph captures the full trace, evaluates the policy, finds relevant precedent, routes the exception for review, shows operators the system state live, and allows replay verification after the decision completes.

The current seeded release-demo tenant packages this into three traces:

- approved precedent:
  - `trace-precedent-renewal-001`
- live exception review:
  - `trace-live-renewal-002`
- incident review:
  - `trace-incident-review-003`

## Actors

- revenue agent service
- decision operations lead
- finance approver
- compliance investigator

## Business Stakes

- the renewal value is high
- the discount is above policy threshold
- the business wants speed, but only with accountability
- the organization must be able to explain and audit the outcome later

## Demo Flow

### Step 1 - Decision Ingestion

The agent submits:

- account and contract context
- requested discount
- supporting facts
- source system references

DecisionGraph records:

- trace start
- input observations
- related entity observations
- policy evaluation events

### Step 2 - Policy Trigger

The system evaluates the discount policy and determines:

- the requested discount exceeds the standard cap
- an exception is required

DecisionGraph records:

- policy evaluation result
- exception request

### Step 3 - Precedent Context

The platform surfaces relevant historical decisions:

- similar strategic renewals
- prior approved exceptions
- matching policy lineage

DecisionGraph shows:

- precedent candidates
- trace links
- comparable context from past cases

### Step 4 - Live Operations View

The decision operations lead opens the operator console and sees:

- projection health
- current trace state
- any lag or replay issues
- queue status for the exception workflow

In the seeded release demo, the live workflow is intentionally escalated already so the operator sees real SLA pressure immediately.

### Step 5 - Human Review

A finance approver opens the approval inbox and reviews:

- the current trace timeline
- policy basis
- precedent context
- supporting evidence

The reviewer records:

- approve or reject
- optional rationale

DecisionGraph records the review event and the decision trail stays intact.

### Step 6 - Action Commit

The approved decision is committed back to the business system.

DecisionGraph records:

- action proposed
- action committed
- final trace outcome

### Step 7 - Replay and Audit Verification

An operator or investigator triggers replay verification and confirms:

- the trace is replayable
- projection digests match expectations
- the full outcome can be reconstructed cleanly

## What This Demo Must Show

- append-only trace integrity
- policy evaluation and exception handling
- precedent-assisted review
- live operator visibility
- human-in-the-loop approval
- deterministic replay and auditability

## How To Run It

From the repository root:

```bash
docker compose up postgres otel-collector -d
cd beam
mix setup
set PHX_SERVER=true
iex -S mix
```

In a second terminal:

```bash
cd beam
mix dg.demo.seed --output ../.tmp/phase10-demo-report.json
```

Start with:

- `http://localhost:4100/?tenant=release-demo&trace_id=trace-live-renewal-002&workflow_id=trace-live-renewal-002:exception:ex-live-renewal-002`
- `http://localhost:4100/?tenant=release-demo&trace_id=trace-incident-review-003&workflow_id=trace-incident-review-003:trace_review:incident_triage`

## Why This Is the Right First Demo

This scenario is ideal because it combines:

- business stakes
- policy complexity
- human review
- operational visibility
- audit pressure

If DecisionGraph looks compelling here, it will feel like a real decision platform instead of a narrow developer utility.
