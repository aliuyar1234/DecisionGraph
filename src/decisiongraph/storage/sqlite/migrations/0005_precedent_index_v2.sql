-- Migration: Replace citation-oriented precedent index with structured lookup rows
-- Version: 0005
-- Description: Precedent index now stores policy/exception lookup data per finished trace

DROP TABLE IF EXISTS dg_precedent_index;

CREATE TABLE dg_precedent_index (
    source_event_id TEXT PRIMARY KEY,
    log_seq INTEGER NOT NULL,
    trace_id TEXT NOT NULL,
    policy_id TEXT NOT NULL,
    policy_version TEXT NOT NULL,
    exception_id TEXT NULL,
    primary_entity_type TEXT NULL,
    primary_entity_system TEXT NULL,
    primary_entity_id TEXT NULL,
    FOREIGN KEY (trace_id) REFERENCES dg_trace_summary(trace_id)
);

CREATE INDEX idx_precedent_policy ON dg_precedent_index (policy_id, policy_version);
CREATE INDEX idx_precedent_trace ON dg_precedent_index (trace_id);
CREATE INDEX idx_precedent_exception ON dg_precedent_index (exception_id);
CREATE INDEX idx_precedent_entity
    ON dg_precedent_index (primary_entity_type, primary_entity_system, primary_entity_id);
CREATE INDEX idx_precedent_log_seq ON dg_precedent_index (log_seq);
