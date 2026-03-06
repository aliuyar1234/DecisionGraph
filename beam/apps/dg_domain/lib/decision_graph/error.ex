defmodule DecisionGraph.Error do
  @moduledoc """
  Shared error type for BEAM-side semantic and storage failures.
  """

  @type code ::
          :conflict
          | :event_sequence_invalid
          | :idempotency_conflict
          | :invalid_argument
          | :pii_policy_violation
          | :schema_violation
          | :storage

  defexception [:code, :message, details: %{}]

  @type t :: %__MODULE__{
          code: code(),
          message: String.t(),
          details: map()
        }

  @impl true
  def exception(opts) do
    %__MODULE__{
      code: Keyword.fetch!(opts, :code),
      message: Keyword.fetch!(opts, :message),
      details: Keyword.get(opts, :details, %{})
    }
  end

  @spec new(code(), String.t(), map()) :: t()
  def new(code, message, details \\ %{}) do
    %__MODULE__{code: code, message: message, details: details}
  end
end
