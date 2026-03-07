defmodule DecisionGraph.Api.Events do
  @moduledoc false

  alias DecisionGraph.Api.Errors
  alias DecisionGraph.Domain.EventEnvelope
  alias DecisionGraph.Projector
  alias DecisionGraph.Store

  @spec append_event(map(), keyword()) :: {:ok, map()} | {:error, DecisionGraph.Api.HttpError.t()}
  def append_event(attrs, opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)
    request_id = Keyword.get(opts, :request_id)

    try do
      envelope = EventEnvelope.new(attrs)
      stored_event = Store.append_event(envelope, tenant_id: tenant_id, request_id: request_id)

      {:ok,
       %{
         event: stored_event,
         projection_sync_triggered: trigger_projection_sync(tenant_id, stored_event)
       }}
    rescue
      error -> {:error, Errors.from_exception(error)}
    end
  end

  defp trigger_projection_sync(tenant_id, stored_event) do
    Enum.each(DecisionGraph.Projector.Runtime.projection_names(), fn projection ->
      case Projector.ensure_worker_started(tenant_id, projection) do
        {:ok, _pid} ->
          :ok =
            Projector.sync(tenant_id, projection, %{
              event_type: stored_event.event_type,
              reason: "api_append"
            })

        {:error, _reason} ->
          raise "failed to start projector worker"
      end
    end)

    true
  rescue
    _error -> false
  end
end
