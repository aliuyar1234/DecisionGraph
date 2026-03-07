defmodule DecisionGraph.Api.Errors do
  @moduledoc false

  alias DecisionGraph.Api.HttpError
  alias DecisionGraph.Api.Serialization
  alias DecisionGraph.Error

  @spec from_exception(term()) :: HttpError.t()
  def from_exception(%HttpError{} = error), do: error

  def from_exception(%Error{} = error) do
    HttpError.new(
      status_for(error.code),
      Atom.to_string(error.code),
      error.message,
      Serialization.serialize(error.details)
    )
  end

  def from_exception(%ArgumentError{message: message}) do
    HttpError.new(400, "invalid_argument", message)
  end

  def from_exception(error) do
    HttpError.new(500, "internal_error", Exception.message(error))
  end

  @spec unauthorized(String.t()) :: HttpError.t()
  def unauthorized(message \\ "Authentication required") do
    HttpError.new(401, "unauthorized", message)
  end

  @spec forbidden(String.t()) :: HttpError.t()
  def forbidden(message \\ "Forbidden") do
    HttpError.new(403, "forbidden", message)
  end

  @spec rate_limited(String.t()) :: HttpError.t()
  def rate_limited(message \\ "Rate limit exceeded") do
    HttpError.new(429, "rate_limited", message)
  end

  @spec invalid_argument(String.t()) :: HttpError.t()
  def invalid_argument(message) do
    HttpError.new(400, "invalid_argument", message)
  end

  defp status_for(:invalid_argument), do: 400
  defp status_for(:not_found), do: 404
  defp status_for(:projection_out_of_date), do: 409
  defp status_for(:storage), do: 503
  defp status_for(:schema_violation), do: 422
  defp status_for(:pii_policy_violation), do: 422
  defp status_for(:event_sequence_invalid), do: 409
  defp status_for(:idempotency_conflict), do: 409
  defp status_for(:conflict), do: 409
end
