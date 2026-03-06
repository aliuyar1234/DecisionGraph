defmodule DecisionGraph.Observability.Application do
  @moduledoc "Starts telemetry pollers and exposes the baseline observability stack."

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      :telemetry_poller.child_spec(
        measurements: [
          {__MODULE__, :emit_vm_metrics, []}
        ],
        period: :timer.seconds(30)
      )
    ]

    DecisionGraph.Observability.emit(
      [:app, :boot],
      %{count: 1},
      %{otp_app: :dg_observability}
    )

    Supervisor.start_link(
      children,
      strategy: :one_for_one,
      name: DecisionGraph.Observability.Supervisor
    )
  end

  def emit_vm_metrics do
    memory = :erlang.memory(:total)

    DecisionGraph.Observability.emit(
      [:vm, :memory],
      %{total: memory},
      %{}
    )
  end
end
