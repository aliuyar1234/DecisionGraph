defmodule DecisionGraph.Domain.EventEnvelope do
  @moduledoc """
  Runtime-side BEAM representation of the frozen event envelope contract.

  The authoritative semantic reference remains the Python implementation; this
  struct mirrors the boundary shape so later phases can work against a stable
  contract.
  """

  alias DecisionGraph.Domain.{ActorRef, SourceRef}

  @enforce_keys [
    :actor,
    :event_id,
    :event_type,
    :idempotency_key,
    :occurred_at,
    :payload,
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
             :occurred_at,
             :payload,
             :schema_version,
             :source,
             :tags,
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
    :occurred_at,
    :payload,
    :source,
    :trace_id,
    :trace_seq,
    schema_version: 1,
    tags: []
  ]

  @type t :: %__MODULE__{
          actor: ActorRef.t(),
          causation_event_id: String.t() | nil,
          correlation_id: String.t() | nil,
          event_id: String.t(),
          event_type: String.t(),
          idempotency_key: String.t(),
          occurred_at: String.t(),
          payload: map(),
          schema_version: pos_integer(),
          source: SourceRef.t(),
          tags: [String.t()],
          trace_id: String.t(),
          trace_seq: non_neg_integer()
        }

  @spec new(map() | keyword()) :: t()
  def new(attrs) do
    attrs = Map.new(attrs)

    %__MODULE__{
      actor: Map.fetch!(attrs, :actor),
      causation_event_id: Map.get(attrs, :causation_event_id),
      correlation_id: Map.get(attrs, :correlation_id),
      event_id: Map.fetch!(attrs, :event_id),
      event_type: Map.fetch!(attrs, :event_type),
      idempotency_key: Map.fetch!(attrs, :idempotency_key),
      occurred_at: Map.fetch!(attrs, :occurred_at),
      payload: Map.fetch!(attrs, :payload),
      schema_version: Map.get(attrs, :schema_version, 1),
      source: Map.fetch!(attrs, :source),
      tags: Map.get(attrs, :tags, []),
      trace_id: Map.fetch!(attrs, :trace_id),
      trace_seq: Map.fetch!(attrs, :trace_seq)
    }
  end
end
