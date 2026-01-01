-- Migration: Create dg_event_log table per SSOT 6.1.4 (PostgreSQL)
-- Version: 0001
-- Description: Main event log table with append-only constraints

CREATE TABLE dg_event_log (
    log_seq BIGSERIAL PRIMARY KEY,
    event_id TEXT UNIQUE NOT NULL,
    trace_id TEXT NOT NULL,
    trace_seq INTEGER NOT NULL,
    event_type TEXT NOT NULL,
    occurred_at TEXT NOT NULL,
    recorded_at TEXT NOT NULL,
    producer_id TEXT NOT NULL,
    system TEXT NOT NULL,
    subsystem TEXT NULL,
    actor_type TEXT NOT NULL,
    actor_id TEXT NOT NULL,
    correlation_id TEXT NULL,
    causation_event_id TEXT NULL,
    idempotency_key TEXT NOT NULL,
    schema_version INTEGER NOT NULL,
    payload_json TEXT NOT NULL,
    payload_hash TEXT NOT NULL,
    tags_json TEXT NOT NULL DEFAULT '[]'
);

-- Unique constraint on (trace_id, trace_seq) per SSOT 6.1.4
CREATE UNIQUE INDEX idx_event_log_trace_seq
    ON dg_event_log (trace_id, trace_seq);

-- Unique constraint on (producer_id, idempotency_key) per SSOT 6.1.4
CREATE UNIQUE INDEX idx_event_log_idempotency
    ON dg_event_log (producer_id, idempotency_key);

-- Index on event_type for filtering per SSOT 6.1.4
CREATE INDEX idx_event_log_event_type
    ON dg_event_log (event_type);

-- Index on correlation_id for correlation queries per SSOT 6.1.4
CREATE INDEX idx_event_log_correlation_id
    ON dg_event_log (correlation_id)
    WHERE correlation_id IS NOT NULL;

-- Index on trace_id for trace lookups
CREATE INDEX idx_event_log_trace_id
    ON dg_event_log (trace_id);
