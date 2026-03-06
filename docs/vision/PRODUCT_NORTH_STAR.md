# Product North Star

## One-Sentence Product Statement

DecisionGraph is the decision operations platform for AI agents and high-stakes automation: it records every decision as an immutable trace, turns those traces into live operational views, and gives developers, operators, reviewers, and auditors a shared control plane to inspect, replay, approve, and recover decisions in production.

## Product Category

DecisionGraph is a combination of:

- developer platform
- operator console
- compliance and audit product
- decision workflow engine

It should not be positioned as only a tracing library or only a workflow product. Its value comes from connecting software integration, runtime operations, and audit-grade decision accountability in one system.

## Primary Problem

Organizations are starting to run important decisions through AI agents and automated systems, but the operating model around those decisions is weak.

Common failure modes:

- teams cannot explain why a decision happened
- operators cannot see whether the decision system is healthy right now
- reviewers cannot intervene cleanly when policy exceptions are needed
- investigators cannot replay or prove what happened after the fact
- engineers build one-off logging and approval flows instead of a durable platform

DecisionGraph exists to make high-stakes automated decisions observable, replayable, governable, and operationally trustworthy.

## Why This Product Matters

The market does not just need smarter AI systems. It needs systems that organizations can trust to operate under real business, regulatory, and incident pressure.

DecisionGraph matters because it aims to answer all of these at once:

- What happened?
- Why did it happen?
- Is the system healthy right now?
- Who approved or overrode it?
- Can we replay it and prove determinism?
- What similar decisions happened before?

If we answer those better than most teams can build internally, the product becomes strategically valuable instead of merely interesting.

## Top Three Product Differentiators

### 1. Deterministic Decision Memory

DecisionGraph is not just event logging. It is an append-only, replayable, digest-verifiable memory for automated decisions. Deterministic replay and stable projection digests are first-class product features.

### 2. Decision Operations Control Plane

DecisionGraph is not just a developer SDK. It gives operators a live system for health monitoring, trace investigation, replay management, precedent lookup, approvals, and exception handling.

### 3. Unified Developer and Governance Surface

DecisionGraph connects ingestion APIs and SDK ergonomics with runtime operations and human oversight. Engineers can integrate it, operators can run it, and compliance teams can trust it.

## Intended Users

Primary users:

- platform and agent engineers
- decision operations leads
- compliance and risk investigators
- human reviewers and approvers

Secondary users:

- reliability engineers
- data and governance teams
- internal platform administrators

## End-State Product Vision

The end-state product should feel like the control room for automated decisions.

Users should be able to:

- ingest decision events from agents and services
- inspect traces in real time
- query context graphs and precedents
- review approvals and exceptions
- detect lag, corruption, or replay drift
- replay the system deterministically
- export evidence for audits and incident analysis

## V1 Must Prove

V1 does not need to prove every future ambition. It must prove these:

- the system can serve as a serious control plane, not just a library
- operators can trust its health and replay surfaces
- human approvals and exception workflows fit naturally into the model
- the product is credible for high-stakes enterprise decision flows

## Internal Positioning

When we make tradeoffs, we should optimize for this identity:

DecisionGraph is the operating system for auditable automated decisions.
