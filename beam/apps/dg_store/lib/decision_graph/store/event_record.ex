defmodule DecisionGraph.Store.EventRecord do
  @moduledoc """
  Ecto schema for the BEAM event log table.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias DecisionGraph.Domain.{ActorRef, SourceRef, StoredEvent}

  @primary_key {:log_seq, :id, autogenerate: true, source: :log_seq}
  schema "dg_event_log" do
    field :tenant_id, :string, default: "default"
    field :event_id, :string
    field :trace_id, :string
    field :trace_seq, :integer
    field :event_type, :string
    field :occurred_at, :string
    field :recorded_at, :string
    field :producer_id, :string
    field :source_system, :string
    field :source_subsystem, :string
    field :actor_type, :string
    field :actor_id, :string
    field :correlation_id, :string
    field :causation_event_id, :string
    field :idempotency_key, :string
    field :schema_version, :integer, default: 1
    field :payload_json, :map
    field :payload_hash, :string
    field :tags_json, {:array, :string}, default: []
  end

  @type t :: %__MODULE__{
          actor_id: String.t() | nil,
          actor_type: String.t() | nil,
          causation_event_id: String.t() | nil,
          correlation_id: String.t() | nil,
          event_id: String.t() | nil,
          event_type: String.t() | nil,
          idempotency_key: String.t() | nil,
          log_seq: integer() | nil,
          occurred_at: DateTime.t() | nil,
          payload_hash: String.t() | nil,
          payload_json: map() | nil,
          producer_id: String.t() | nil,
          recorded_at: DateTime.t() | nil,
          schema_version: integer() | nil,
          source_subsystem: String.t() | nil,
          source_system: String.t() | nil,
          tags_json: [String.t()] | nil,
          tenant_id: String.t() | nil,
          trace_id: String.t() | nil,
          trace_seq: integer() | nil
        }

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :tenant_id,
      :event_id,
      :trace_id,
      :trace_seq,
      :event_type,
      :occurred_at,
      :recorded_at,
      :producer_id,
      :source_system,
      :source_subsystem,
      :actor_type,
      :actor_id,
      :correlation_id,
      :causation_event_id,
      :idempotency_key,
      :schema_version,
      :payload_json,
      :payload_hash,
      :tags_json
    ])
    |> validate_required([
      :tenant_id,
      :event_id,
      :trace_id,
      :trace_seq,
      :event_type,
      :occurred_at,
      :recorded_at,
      :producer_id,
      :source_system,
      :actor_type,
      :actor_id,
      :idempotency_key,
      :schema_version,
      :payload_json,
      :payload_hash,
      :tags_json
    ])
  end

  @spec to_stored_event(t()) :: StoredEvent.t()
  def to_stored_event(%__MODULE__{} = record) do
    StoredEvent.new(
      actor: %ActorRef{
        actor_id: record.actor_id,
        actor_type: record.actor_type
      },
      causation_event_id: record.causation_event_id,
      correlation_id: record.correlation_id,
      event_id: record.event_id,
      event_type: record.event_type,
      idempotency_key: record.idempotency_key,
      log_seq: record.log_seq,
      occurred_at: record.occurred_at,
      payload: decode_json_map(record.payload_json),
      payload_hash: record.payload_hash,
      recorded_at: record.recorded_at,
      schema_version: record.schema_version,
      source: %SourceRef{
        producer_id: record.producer_id,
        subsystem: record.source_subsystem,
        system: record.source_system
      },
      tags: decode_json_list(record.tags_json),
      tenant_id: record.tenant_id,
      trace_id: record.trace_id,
      trace_seq: record.trace_seq
    )
  end

  defp decode_json_map(nil), do: %{}
  defp decode_json_map(value), do: Jason.decode!(value)

  defp decode_json_list(nil), do: []
  defp decode_json_list(value), do: Jason.decode!(value)
end
