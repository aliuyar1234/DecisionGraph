defmodule DecisionGraph.Store.Repo.Migrations.CreateDgProjectionCursors do
  use Ecto.Migration

  def change do
    create table(:dg_projection_cursors, primary_key: false) do
      add(:tenant_id, :text, null: false, default: "default")
      add(:projection_name, :text, null: false)
      add(:last_log_seq, :bigint, null: false, default: 0)
      add(:updated_at, :text, null: false)
    end

    create(
      unique_index(:dg_projection_cursors, [:tenant_id, :projection_name],
        name: :dg_projection_cursors_pk
      )
    )

    create(
      index(:dg_projection_cursors, [:tenant_id, :last_log_seq],
        name: :dg_projection_cursors_log_seq_idx
      )
    )
  end
end
