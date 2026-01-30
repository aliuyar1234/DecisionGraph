-- Migration: Create policy evaluation index
-- Version: 0003
-- Description: Index traces by evaluated policy for faster precedent search

CREATE TABLE dg_policy_eval_index (
    index_id TEXT PRIMARY KEY,
    trace_id TEXT NOT NULL,
    policy_id TEXT NOT NULL,
    policy_version TEXT NOT NULL,
    log_seq INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (trace_id) REFERENCES dg_trace_summary(trace_id)
);

CREATE INDEX idx_policy_eval_policy_id ON dg_policy_eval_index (policy_id);
CREATE INDEX idx_policy_eval_policy_version ON dg_policy_eval_index (policy_id, policy_version);
CREATE INDEX idx_policy_eval_trace_id ON dg_policy_eval_index (trace_id);
