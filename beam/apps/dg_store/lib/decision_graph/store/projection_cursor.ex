defmodule DecisionGraph.Store.ProjectionCursor do
  @moduledoc """
  Reserved Phase 4 handoff table for projection cursor ownership.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  schema "dg_projection_cursors" do
    field :tenant_id, :string
    field :projection_name, :string
    field :last_log_seq, :integer, default: 0
    field :updated_at, :string
  end

  @type t :: %__MODULE__{
          last_log_seq: integer() | nil,
          projection_name: String.t() | nil,
          tenant_id: String.t() | nil,
          updated_at: String.t() | nil
        }

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(cursor, attrs) do
    cursor
    |> cast(attrs, [:tenant_id, :projection_name, :last_log_seq, :updated_at])
    |> validate_required([:tenant_id, :projection_name, :last_log_seq, :updated_at])
  end
end
