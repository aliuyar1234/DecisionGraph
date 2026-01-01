-- Migration: Create projection tables for causality graph (PostgreSQL)
-- Version: 0002
-- Description: Tables for projections (P3/P4 preparation)

-- Causality graph nodes
CREATE TABLE dg_cg_nodes (
    node_id TEXT PRIMARY KEY,
    node_type TEXT NOT NULL,
    trace_id TEXT NOT NULL,
    log_seq BIGINT NOT NULL,
    created_at TEXT NOT NULL,
    metadata_json TEXT NOT NULL DEFAULT '{}'
);

CREATE INDEX idx_cg_nodes_trace_id ON dg_cg_nodes (trace_id);
CREATE INDEX idx_cg_nodes_type ON dg_cg_nodes (node_type);

-- Causality graph edges
CREATE TABLE dg_cg_edges (
    edge_id TEXT PRIMARY KEY,
    edge_type TEXT NOT NULL,
    from_node_id TEXT NOT NULL,
    to_node_id TEXT NOT NULL,
    trace_id TEXT NOT NULL,
    log_seq BIGINT NOT NULL,
    created_at TEXT NOT NULL,
    metadata_json TEXT NOT NULL DEFAULT '{}',
    FOREIGN KEY (from_node_id) REFERENCES dg_cg_nodes(node_id),
    FOREIGN KEY (to_node_id) REFERENCES dg_cg_nodes(node_id)
);

CREATE INDEX idx_cg_edges_from ON dg_cg_edges (from_node_id);
CREATE INDEX idx_cg_edges_to ON dg_cg_edges (to_node_id);
CREATE INDEX idx_cg_edges_trace_id ON dg_cg_edges (trace_id);
CREATE INDEX idx_cg_edges_type ON dg_cg_edges (edge_type);

-- Trace summary for quick lookups
CREATE TABLE dg_trace_summary (
    trace_id TEXT PRIMARY KEY,
    workflow TEXT NOT NULL,
    title TEXT NOT NULL,
    primary_entity_type TEXT NULL,
    primary_entity_id TEXT NULL,
    outcome TEXT NULL,
    started_at TEXT NOT NULL,
    finished_at TEXT NULL,
    event_count INTEGER NOT NULL DEFAULT 0,
    last_log_seq BIGINT NOT NULL
);

CREATE INDEX idx_trace_summary_workflow ON dg_trace_summary (workflow);
CREATE INDEX idx_trace_summary_outcome ON dg_trace_summary (outcome);

-- Precedent index for similarity lookups
CREATE TABLE dg_precedent_index (
    index_id TEXT PRIMARY KEY,
    trace_id TEXT NOT NULL,
    cited_trace_id TEXT NOT NULL,
    reason TEXT NOT NULL,
    similarity_score TEXT NULL,
    log_seq BIGINT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (trace_id) REFERENCES dg_trace_summary(trace_id)
);

CREATE INDEX idx_precedent_trace_id ON dg_precedent_index (trace_id);
CREATE INDEX idx_precedent_cited ON dg_precedent_index (cited_trace_id);

-- Projection metadata for tracking projection state
CREATE TABLE dg_projection_meta (
    projection_name TEXT PRIMARY KEY,
    last_processed_log_seq BIGINT NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL
);
