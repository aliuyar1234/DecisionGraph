defmodule DecisionGraph.Store.EventFactory do
  @moduledoc false

  alias DecisionGraph.Domain.{ActorRef, EventEnvelope, SourceRef}

  @spec trace_started(String.t(), map()) :: EventEnvelope.t()
  def trace_started(trace_id, overrides \\ %{}) do
    build_envelope(
      Map.merge(
        %{
          event_type: "TraceStarted",
          idempotency_key: "start:#{trace_id}",
          payload: %{
            "primary_entity" => %{
              "entity_id" => "entity:#{trace_id}",
              "entity_type" => "account",
              "system" => "crm"
            },
            "title" => "Trace #{trace_id}",
            "workflow" => "phase3_store"
          },
          trace_id: trace_id,
          trace_seq: 0
        },
        overrides
      )
    )
  end

  @spec input_observed(String.t(), non_neg_integer(), map()) :: EventEnvelope.t()
  def input_observed(trace_id, trace_seq, overrides \\ %{}) do
    build_envelope(
      Map.merge(
        %{
          event_type: "InputObserved",
          idempotency_key: "input:#{trace_id}:#{trace_seq}",
          payload: %{
            "facts" => [],
            "input_id" => "input:#{trace_id}:#{trace_seq}",
            "source" => %{
              "object_id" => "object:#{trace_id}",
              "object_type" => "account",
              "system" => "crm"
            }
          },
          trace_id: trace_id,
          trace_seq: trace_seq
        },
        overrides
      )
    )
  end

  @spec policy_evaluated(String.t(), non_neg_integer(), map()) :: EventEnvelope.t()
  def policy_evaluated(trace_id, trace_seq, overrides \\ %{}) do
    build_envelope(
      Map.merge(
        %{
          event_type: "PolicyEvaluated",
          idempotency_key: "policy:#{trace_id}:#{trace_seq}",
          payload: %{
            "decision" => "allow",
            "inputs" => ["input:#{trace_id}:1"],
            "policy" => %{
              "policy_id" => "sync_guard",
              "policy_version" => "1.0"
            },
            "violations" => []
          },
          trace_id: trace_id,
          trace_seq: trace_seq
        },
        overrides
      )
    )
  end

  @spec trace_finished(String.t(), non_neg_integer(), map()) :: EventEnvelope.t()
  def trace_finished(trace_id, trace_seq, overrides \\ %{}) do
    build_envelope(
      Map.merge(
        %{
          event_type: "TraceFinished",
          idempotency_key: "finish:#{trace_id}",
          payload: %{
            "outcome" => "success",
            "summary" => "Finished #{trace_id}"
          },
          trace_id: trace_id,
          trace_seq: trace_seq
        },
        overrides
      )
    )
  end

  @spec build_envelope(map()) :: EventEnvelope.t()
  def build_envelope(attrs) do
    actor = Map.get(attrs, :actor, %{})
    source = Map.get(attrs, :source, %{})

    attrs =
      attrs
      |> Map.new()
      |> Map.put_new(:actor, normalize_actor(actor))
      |> Map.put_new(:causation_event_id, nil)
      |> Map.put_new(:correlation_id, nil)
      |> Map.put_new_lazy(:event_id, fn ->
        event_type = Map.fetch!(attrs, :event_type) |> to_string() |> Macro.underscore()
        trace_id = Map.fetch!(attrs, :trace_id)
        trace_seq = Map.fetch!(attrs, :trace_seq)
        "#{trace_id}-#{event_type}-#{trace_seq}"
      end)
      |> Map.put_new_lazy(:occurred_at, fn -> occurred_at(Map.fetch!(attrs, :trace_seq)) end)
      |> Map.put_new(:schema_version, 1)
      |> Map.put_new(:source, normalize_source(source))
      |> Map.put_new(:tags, [])

    EventEnvelope.new(attrs)
  end

  defp actor_defaults(overrides) do
    Map.merge(
      %{
        actor_id: "store-agent",
        actor_type: "agent"
      },
      Map.new(overrides)
    )
  end

  defp source_defaults(overrides) do
    Map.merge(
      %{
        producer_id: "store-service",
        subsystem: nil,
        system: "store-runtime"
      },
      Map.new(overrides)
    )
  end

  defp normalize_actor(%ActorRef{} = actor), do: actor
  defp normalize_actor(overrides), do: ActorRef.new(actor_defaults(overrides))

  defp normalize_source(%SourceRef{} = source), do: source
  defp normalize_source(overrides), do: SourceRef.new(source_defaults(overrides))

  defp occurred_at(trace_seq) do
    "2025-12-31T12:00:#{trace_seq |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")}Z"
  end
end
