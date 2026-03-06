defmodule DecisionGraph.Domain.ActorRef do
  @moduledoc "Actor reference used by delivery and runtime layers."

  @enforce_keys [:actor_id, :actor_type]
  @derive {Jason.Encoder, only: [:actor_id, :actor_type]}
  defstruct [:actor_id, :actor_type]

  @type actor_type :: :agent | :person | :role | :system
  @type t :: %__MODULE__{
          actor_id: String.t(),
          actor_type: actor_type()
        }
end
