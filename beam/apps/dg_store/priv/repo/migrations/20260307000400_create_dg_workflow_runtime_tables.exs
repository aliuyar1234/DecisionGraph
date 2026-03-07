defmodule DecisionGraph.Store.Repo.Migrations.CreateDgWorkflowRuntimeTables do
  use Ecto.Migration

  def up do
    create table(:dg_workflow_runtime, primary_key: false) do
      add(:tenant_id, :text, primary_key: true)
      add(:last_log_seq, :bigint, null: false, default: 0)
      add(:updated_at, :text, null: false)
    end

    create table(:dg_workflow_items, primary_key: false) do
      add(:workflow_id, :text, primary_key: true)
      add(:tenant_id, :text, null: false, default: "default")
      add(:trace_id, :text, null: false)
      add(:workflow_kind, :text, null: false)
      add(:workflow_name, :text)
      add(:subject_type, :text, null: false)
      add(:subject_id, :text, null: false)
      add(:status, :text, null: false)
      add(:priority, :text, null: false, default: "high")
      add(:title, :text, null: false)
      add(:policy_id, :text)
      add(:policy_version, :text)
      add(:requested_by_actor_id, :text)
      add(:requested_by_actor_type, :text)
      add(:assigned_account_id, :text)
      add(:assigned_role, :text)
      add(:requested_at, :text, null: false)
      add(:sla_due_at, :text)
      add(:updated_at, :text, null: false)
      add(:resolved_at, :text)
      add(:last_action_type, :text)
      add(:last_action_at, :text)
      add(:current_decision, :text)
      add(:current_reason, :text)
      add(:approval_event_id, :text)
      add(:created_from_event_id, :text, null: false)
      add(:last_source_log_seq, :bigint, null: false, default: 0)
      add(:metadata_json, :text, null: false, default: "{}")
    end

    create(
      unique_index(:dg_workflow_items, [:tenant_id, :trace_id, :subject_type, :subject_id],
        name: :dg_workflow_items_trace_subject_idx
      )
    )

    create(index(:dg_workflow_items, [:tenant_id, :status], name: :dg_workflow_items_status_idx))
    create(index(:dg_workflow_items, [:tenant_id, :trace_id], name: :dg_workflow_items_trace_idx))

    create(
      index(:dg_workflow_items, [:tenant_id, :assigned_account_id],
        name: :dg_workflow_items_assignee_idx
      )
    )

    create(
      index(:dg_workflow_items, [:tenant_id, :assigned_role], name: :dg_workflow_items_role_idx)
    )

    create(index(:dg_workflow_items, [:tenant_id, :sla_due_at], name: :dg_workflow_items_sla_idx))

    create(
      index(:dg_workflow_items, [:tenant_id, :last_source_log_seq],
        name: :dg_workflow_items_log_idx
      )
    )

    create table(:dg_workflow_actions, primary_key: false) do
      add(:action_id, :text, primary_key: true)
      add(:tenant_id, :text, null: false, default: "default")
      add(:workflow_id, :text, null: false)
      add(:trace_id, :text, null: false)
      add(:action_type, :text, null: false)
      add(:actor_id, :text)
      add(:actor_type, :text)
      add(:actor_account_id, :text)
      add(:note, :text)
      add(:payload_json, :text, null: false, default: "{}")
      add(:source_event_id, :text)
      add(:resulting_status, :text)
      add(:created_at, :text, null: false)
    end

    create(
      unique_index(:dg_workflow_actions, [:tenant_id, :source_event_id],
        name: :dg_workflow_actions_source_event_idx
      )
    )

    create(
      index(:dg_workflow_actions, [:tenant_id, :workflow_id, :created_at],
        name: :dg_workflow_actions_workflow_idx
      )
    )

    create(
      index(:dg_workflow_actions, [:tenant_id, :action_type], name: :dg_workflow_actions_type_idx)
    )
  end

  def down do
    drop(table(:dg_workflow_actions))
    drop(table(:dg_workflow_items))
    drop(table(:dg_workflow_runtime))
  end
end
