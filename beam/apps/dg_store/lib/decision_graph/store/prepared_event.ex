defmodule DecisionGraph.Store.PreparedEvent do
  @moduledoc """
  Validation and normalization pipeline for Elixir-side event appends.
  """

  alias DecisionGraph.Domain.{
    CanonicalJson,
    EventEnvelope,
    Validation
  }

  alias DecisionGraph.Error

  @enforce_keys [:envelope, :occurred_at, :payload_hash, :recorded_at]
  defstruct [:envelope, :occurred_at, :payload_hash, :recorded_at]

  @type t :: %__MODULE__{
          envelope: EventEnvelope.t(),
          occurred_at: DateTime.t(),
          payload_hash: String.t(),
          recorded_at: DateTime.t()
        }

  @spec prepare!(EventEnvelope.t()) :: t()
  def prepare!(%EventEnvelope{} = envelope) do
    normalized_envelope = normalize_envelope(envelope)
    Validation.validate_envelope!(normalized_envelope)

    %__MODULE__{
      envelope: normalized_envelope,
      occurred_at: parse_timestamp!(normalized_envelope.occurred_at, :occurred_at),
      payload_hash: CanonicalJson.compute_payload_hash!(normalized_envelope.payload),
      recorded_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
    }
  end

  defp normalize_envelope(%EventEnvelope{} = envelope) do
    payload =
      envelope.payload
      |> CanonicalJson.canonicalize!()
      |> Jason.decode!()

    %EventEnvelope{
      (envelope
       |> Map.from_struct()
       |> EventEnvelope.new())
      | payload: payload,
        tags: Enum.map(envelope.tags, &normalize_tag/1)
    }
  end

  defp normalize_tag(tag), do: tag |> to_string() |> String.trim()

  defp parse_timestamp!(value, field) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        DateTime.truncate(datetime, :microsecond)

      {:error, _reason} ->
        raise Error,
          code: :invalid_argument,
          message: "#{field} must be a valid RFC3339 timestamp, got: #{inspect(value)}"
    end
  end
end
