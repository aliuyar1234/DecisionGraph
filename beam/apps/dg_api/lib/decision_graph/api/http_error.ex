defmodule DecisionGraph.Api.HttpError do
  @moduledoc false

  defexception [:status, :code, :message, details: %{}]

  @type t :: %__MODULE__{
          status: pos_integer(),
          code: String.t(),
          message: String.t(),
          details: map()
        }

  @spec new(pos_integer(), String.t(), String.t(), map()) :: t()
  def new(status, code, message, details \\ %{}) do
    %__MODULE__{
      status: status,
      code: code,
      message: message,
      details: details
    }
  end
end
