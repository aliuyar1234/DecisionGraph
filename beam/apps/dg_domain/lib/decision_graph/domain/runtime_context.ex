defmodule DecisionGraph.Domain.RuntimeContext do
  @moduledoc """
  Shared request and worker context propagated through the platform runtime.
  """

  @enforce_keys [:request_id]
  @derive {Jason.Encoder, only: [:deployment_env, :request_id, :tenant_id, :trace_id]}
  defstruct [:deployment_env, :request_id, :tenant_id, :trace_id]

  @type t :: %__MODULE__{
          deployment_env: String.t() | nil,
          request_id: String.t(),
          tenant_id: String.t() | nil,
          trace_id: String.t() | nil
        }

  @spec new(map() | keyword()) :: t()
  def new(attrs) do
    attrs = Map.new(attrs)

    %__MODULE__{
      deployment_env: normalize(attrs[:deployment_env]),
      request_id: normalize_required(attrs[:request_id]),
      tenant_id: normalize(attrs[:tenant_id]),
      trace_id: normalize(attrs[:trace_id])
    }
  end

  @spec logger_metadata(t()) :: keyword()
  def logger_metadata(%__MODULE__{} = context) do
    context
    |> Map.take([:request_id, :tenant_id, :trace_id])
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp normalize_required(nil), do: raise(ArgumentError, "request_id is required")
  defp normalize_required(value), do: normalize(value)

  defp normalize(nil), do: nil
  defp normalize(value) when is_binary(value), do: String.trim(value)
  defp normalize(value), do: to_string(value)
end
