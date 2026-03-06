defmodule DecisionGraph.Domain.SourceRef do
  @moduledoc "Source metadata attached to ingested events."

  @enforce_keys [:producer_id, :system]
  @derive {Jason.Encoder, only: [:producer_id, :subsystem, :system]}
  defstruct [:producer_id, :subsystem, :system]

  @type t :: %__MODULE__{
          producer_id: String.t(),
          subsystem: String.t() | nil,
          system: String.t()
        }
end
