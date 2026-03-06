defmodule DecisionGraph.Domain.StoredEvent do
  @moduledoc """
  Persisted event envelope with store-assigned metadata.
  """

  alias DecisionGraph.Domain.{ActorRef, SourceRef}

  @enforce_keys [
    :actor,
    :event_id,
    :event_type,
    :idempotency_key,
    :log_seq,
    :occurred_at,
    :payload,
    :payload_hash,
    :recorded_at,
    :source,
    :trace_id,
    :trace_seq
  ]
  @derive {Jason.Encoder,
           only: [
             :actor,
             :causation_event_id,
             :correlation_id,
             :event_id,
             :event_type,
             :idempotency_key,
             :log_seq,
             :occurred_at,
             :payload,
             :payload_hash,
             :recorded_at,
             :schema_version,
             :source,
             :tags,
             :tenant_id,
             :trace_id,
             :trace_seq
           ]}
  defstruct [
    :actor,
    :causation_event_id,
    :correlation_id,
    :event_id,
    :event_type,
    :idempotency_key,
    :log_seq,
    :occurred_at,
    :payload,
    :payload_hash,
    :recorded_at,
    :source,
    :trace_id,
    :trace_seq,
    schema_version: 1,
    tags: [],
    tenant_id: "default"
  ]

  @type t :: %__MODULE__{
          actor: ActorRef.t(),
          causation_event_id: String.t() | nil,
          correlation_id: String.t() | nil,
          event_id: String.t(),
          event_type: String.t(),
          idempotency_key: String.t(),
          log_seq: pos_integer(),
          occurred_at: String.t(),
          payload: map(),
          payload_hash: String.t(),
          recorded_at: String.t(),
          schema_version: pos_integer(),
          source: SourceRef.t(),
          tags: [String.t()],
          tenant_id: String.t(),
          trace_id: String.t(),
          trace_seq: non_neg_integer()
        }

  @spec new(map() | keyword()) :: t()
  def new(attrs) do
    attrs = Map.new(attrs)

    %__MODULE__{
      actor: attrs |> fetch!(:actor) |> normalize_actor(),
      causation_event_id: attrs |> fetch_optional(:causation_event_id) |> normalize_optional(),
      correlation_id: attrs |> fetch_optional(:correlation_id) |> normalize_optional(),
      event_id: attrs |> fetch!(:event_id) |> normalize_required!(:event_id),
      event_type: attrs |> fetch!(:event_type) |> normalize_required!(:event_type),
      idempotency_key: attrs |> fetch!(:idempotency_key) |> normalize_required!(:idempotency_key),
      log_seq: attrs |> fetch!(:log_seq) |> normalize_positive_integer!(:log_seq),
      occurred_at: attrs |> fetch!(:occurred_at) |> normalize_required!(:occurred_at),
      payload: attrs |> fetch!(:payload) |> normalize_payload!(),
      payload_hash: attrs |> fetch!(:payload_hash) |> normalize_required!(:payload_hash),
      recorded_at: attrs |> fetch!(:recorded_at) |> normalize_required!(:recorded_at),
      schema_version:
        attrs
        |> fetch_optional(:schema_version, 1)
        |> normalize_positive_integer!(:schema_version),
      source: attrs |> fetch!(:source) |> normalize_source(),
      tags: attrs |> fetch_optional(:tags, []) |> normalize_tags(),
      tenant_id:
        attrs |> fetch_optional(:tenant_id, "default") |> normalize_required!(:tenant_id),
      trace_id: attrs |> fetch!(:trace_id) |> normalize_required!(:trace_id),
      trace_seq: attrs |> fetch!(:trace_seq) |> normalize_non_negative_integer!(:trace_seq)
    }
  end

  defp fetch!(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.fetch!(attrs, Atom.to_string(key))
    end
  end

  defp fetch_optional(attrs, key, default \\ nil) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))
  end

  defp normalize_actor(%ActorRef{} = actor), do: actor
  defp normalize_actor(attrs), do: ActorRef.new(attrs)

  defp normalize_source(%SourceRef{} = source), do: source
  defp normalize_source(attrs), do: SourceRef.new(attrs)

  defp normalize_required!(value, key) when is_binary(value) do
    value = String.trim(value)

    if value == "" do
      raise ArgumentError, "#{key} is required"
    end

    value
  end

  defp normalize_required!(value, key) when not is_nil(value) do
    value
    |> to_string()
    |> normalize_required!(key)
  end

  defp normalize_required!(_value, key), do: raise(ArgumentError, "#{key} is required")

  defp normalize_optional(nil), do: nil
  defp normalize_optional(value) when is_binary(value), do: String.trim(value)
  defp normalize_optional(value), do: value |> to_string() |> normalize_optional()

  defp normalize_payload!(payload) when is_map(payload), do: payload

  defp normalize_payload!(payload) do
    raise ArgumentError, "payload must be a map, got: #{inspect(payload)}"
  end

  defp normalize_tags(tags) when is_list(tags) do
    Enum.map(tags, fn tag -> tag |> to_string() |> String.trim() end)
  end

  defp normalize_tags(tags) do
    raise ArgumentError, "tags must be a list, got: #{inspect(tags)}"
  end

  defp normalize_positive_integer!(value, _key) when is_integer(value) and value > 0, do: value

  defp normalize_positive_integer!(value, key),
    do: raise(ArgumentError, "#{key} must be > 0, got: #{inspect(value)}")

  defp normalize_non_negative_integer!(value, _key) when is_integer(value) and value >= 0,
    do: value

  defp normalize_non_negative_integer!(value, key) do
    raise ArgumentError, "#{key} must be >= 0, got: #{inspect(value)}"
  end
end
