defmodule DecisionGraph.Store.Repo.Migrations.CreateDgProjectionRuntimeTables do
  use Ecto.Migration

  def up do
    create table(:dg_cg_nodes, primary_key: false) do
      add(:tenant_id, :text, null: false, default: "default")
      add(:node_id, :text, null: false)
      add(:node_type, :text, null: false)
      add(:trace_id, :text, null: false)
      add(:log_seq, :bigint, null: false)
      add(:created_at, :text, null: false)
      add(:metadata_json, :text, null: false, default: "{}")
    end

    create(unique_index(:dg_cg_nodes, [:tenant_id, :node_id], name: :dg_cg_nodes_pk))
    create(index(:dg_cg_nodes, [:tenant_id, :trace_id], name: :dg_cg_nodes_trace_idx))
    create(index(:dg_cg_nodes, [:tenant_id, :node_type], name: :dg_cg_nodes_type_idx))

    create table(:dg_cg_edges, primary_key: false) do
      add(:tenant_id, :text, null: false, default: "default")
      add(:edge_id, :text, null: false)
      add(:edge_type, :text, null: false)
      add(:from_node_id, :text, null: false)
      add(:to_node_id, :text, null: false)
      add(:trace_id, :text, null: false)
      add(:log_seq, :bigint, null: false)
      add(:created_at, :text, null: false)
      add(:metadata_json, :text, null: false, default: "{}")
    end

    create(unique_index(:dg_cg_edges, [:tenant_id, :edge_id], name: :dg_cg_edges_pk))
    create(index(:dg_cg_edges, [:tenant_id, :trace_id], name: :dg_cg_edges_trace_idx))
    create(index(:dg_cg_edges, [:tenant_id, :edge_type], name: :dg_cg_edges_type_idx))
    create(index(:dg_cg_edges, [:tenant_id, :from_node_id], name: :dg_cg_edges_from_idx))
    create(index(:dg_cg_edges, [:tenant_id, :to_node_id], name: :dg_cg_edges_to_idx))
    create(index(:dg_cg_edges, [:tenant_id, :log_seq, :edge_id], name: :dg_cg_edges_log_idx))

    create table(:dg_trace_summary, primary_key: false) do
      add(:tenant_id, :text, null: false, default: "default")
      add(:trace_id, :text, null: false)
      add(:workflow, :text, null: false)
      add(:title, :text, null: false)
      add(:primary_entity_type, :text)
      add(:primary_entity_system, :text)
      add(:primary_entity_id, :text)
      add(:outcome, :text)
      add(:started_at, :text, null: false)
      add(:finished_at, :text)
      add(:event_count, :integer, null: false, default: 0)
      add(:last_log_seq, :bigint, null: false)
    end

    create(unique_index(:dg_trace_summary, [:tenant_id, :trace_id], name: :dg_trace_summary_pk))

    create(
      index(:dg_trace_summary, [:tenant_id, :workflow], name: :dg_trace_summary_workflow_idx)
    )

    create(index(:dg_trace_summary, [:tenant_id, :outcome], name: :dg_trace_summary_outcome_idx))
    create(index(:dg_trace_summary, [:tenant_id, :last_log_seq], name: :dg_trace_summary_log_idx))

    create table(:dg_policy_eval_index, primary_key: false) do
      add(:tenant_id, :text, null: false, default: "default")
      add(:index_id, :text, null: false)
      add(:trace_id, :text, null: false)
      add(:policy_id, :text, null: false)
      add(:policy_version, :text, null: false)
      add(:log_seq, :bigint, null: false)
      add(:created_at, :text, null: false)
    end

    create(
      unique_index(:dg_policy_eval_index, [:tenant_id, :index_id], name: :dg_policy_eval_index_pk)
    )

    create(index(:dg_policy_eval_index, [:tenant_id, :trace_id], name: :dg_policy_eval_trace_idx))

    create(
      index(:dg_policy_eval_index, [:tenant_id, :policy_id, :policy_version],
        name: :dg_policy_eval_policy_idx
      )
    )

    create table(:dg_precedent_index, primary_key: false) do
      add(:tenant_id, :text, null: false, default: "default")
      add(:source_event_id, :text, null: false)
      add(:log_seq, :bigint, null: false)
      add(:trace_id, :text, null: false)
      add(:policy_id, :text, null: false)
      add(:policy_version, :text, null: false)
      add(:exception_id, :text)
      add(:primary_entity_type, :text)
      add(:primary_entity_system, :text)
      add(:primary_entity_id, :text)
    end

    create(
      unique_index(:dg_precedent_index, [:tenant_id, :source_event_id],
        name: :dg_precedent_index_pk
      )
    )

    create(index(:dg_precedent_index, [:tenant_id, :trace_id], name: :dg_precedent_trace_idx))

    create(
      index(:dg_precedent_index, [:tenant_id, :policy_id, :policy_version],
        name: :dg_precedent_policy_idx
      )
    )

    create(
      index(:dg_precedent_index, [:tenant_id, :primary_entity_type, :primary_entity_id],
        name: :dg_precedent_entity_idx
      )
    )

    create(index(:dg_precedent_index, [:tenant_id, :log_seq], name: :dg_precedent_log_idx))

    create table(:dg_projection_digests, primary_key: false) do
      add(:tenant_id, :text, null: false, default: "default")
      add(:projection_name, :text, null: false)
      add(:digest_value, :text, null: false)
      add(:last_log_seq, :bigint, null: false, default: 0)
      add(:updated_at, :text, null: false)
    end

    create(
      unique_index(:dg_projection_digests, [:tenant_id, :projection_name],
        name: :dg_projection_digests_pk
      )
    )

    create(
      index(:dg_projection_digests, [:tenant_id, :last_log_seq],
        name: :dg_projection_digests_log_idx
      )
    )

    create table(:dg_projection_failures) do
      add(:tenant_id, :text, null: false, default: "default")
      add(:projection_name, :text, null: false)
      add(:log_seq, :bigint, null: false)
      add(:trace_id, :text, null: false)
      add(:event_id, :text, null: false)
      add(:error_code, :text, null: false)
      add(:error_message, :text, null: false)
      add(:recoverable, :boolean, null: false, default: false)
      add(:retry_count, :integer, null: false, default: 0)
      add(:status, :text, null: false, default: "open")
      add(:metadata_json, :text, null: false, default: "{}")
      add(:recorded_at, :text, null: false)
      add(:resolved_at, :text)
    end

    create(
      index(:dg_projection_failures, [:tenant_id, :projection_name, :status],
        name: :dg_projection_failures_status_idx
      )
    )

    create(
      index(:dg_projection_failures, [:tenant_id, :projection_name, :log_seq],
        name: :dg_projection_failures_log_idx
      )
    )

    create table(:dg_projection_runs, primary_key: false) do
      add(:job_id, :text, primary_key: true)
      add(:tenant_id, :text, null: false, default: "default")
      add(:projection_name, :text, null: false)
      add(:mode, :text, null: false)
      add(:status, :text, null: false)
      add(:requested_at, :text, null: false)
      add(:started_at, :text)
      add(:finished_at, :text)
      add(:since_log_seq, :bigint, null: false, default: 0)
      add(:until_log_seq, :bigint)
      add(:processed_events, :integer, null: false, default: 0)
      add(:last_log_seq, :bigint, null: false, default: 0)
      add(:error_code, :text)
      add(:error_message, :text)
      add(:metadata_json, :text, null: false, default: "{}")
    end

    create(
      index(:dg_projection_runs, [:tenant_id, :projection_name],
        name: :dg_projection_runs_scope_idx
      )
    )

    create(
      index(:dg_projection_runs, [:status, :requested_at], name: :dg_projection_runs_status_idx)
    )
  end

  def down do
    drop(table(:dg_projection_runs))
    drop(table(:dg_projection_failures))
    drop(table(:dg_projection_digests))
    drop(table(:dg_precedent_index))
    drop(table(:dg_policy_eval_index))
    drop(table(:dg_trace_summary))
    drop(table(:dg_cg_edges))
    drop(table(:dg_cg_nodes))
  end
end
