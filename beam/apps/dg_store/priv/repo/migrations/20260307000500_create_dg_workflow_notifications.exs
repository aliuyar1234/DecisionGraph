defmodule DecisionGraph.Store.Repo.Migrations.CreateDgWorkflowNotifications do
  use Ecto.Migration

  def up do
    create table(:dg_workflow_notifications, primary_key: false) do
      add(:notification_id, :text, primary_key: true)
      add(:tenant_id, :text, null: false, default: "default")
      add(:workflow_id, :text, null: false)
      add(:trace_id, :text, null: false)
      add(:category, :text, null: false)
      add(:channel, :text, null: false, default: "operator_console")
      add(:status, :text, null: false, default: "delivered")
      add(:message, :text, null: false)
      add(:recipient_account_id, :text)
      add(:recipient_role, :text)
      add(:payload_json, :text, null: false, default: "{}")
      add(:dedupe_key, :text, null: false)
      add(:created_at, :text, null: false)
      add(:delivered_at, :text, null: false)
    end

    create(
      unique_index(:dg_workflow_notifications, [:tenant_id, :dedupe_key],
        name: :dg_workflow_notifications_dedupe_idx
      )
    )

    create(
      index(:dg_workflow_notifications, [:tenant_id, :workflow_id, :created_at],
        name: :dg_workflow_notifications_workflow_idx
      )
    )

    create(
      index(:dg_workflow_notifications, [:tenant_id, :category, :created_at],
        name: :dg_workflow_notifications_category_idx
      )
    )
  end

  def down do
    drop(table(:dg_workflow_notifications))
  end
end
