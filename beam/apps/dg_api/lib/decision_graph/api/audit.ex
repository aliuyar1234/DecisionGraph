defmodule DecisionGraph.Api.Audit do
  @moduledoc false

  require Logger

  alias DecisionGraph.Observability

  @spec admin_action(atom(), :accepted | :rejected, keyword()) :: :ok
  def admin_action(action, outcome, opts \\ []) do
    metadata = metadata(action, outcome, opts)

    Logger.log(
      log_level(outcome),
      "api_admin_#{action}_#{outcome}",
      Enum.into(metadata, [])
    )

    Observability.emit(
      [:api, :admin, :audit],
      %{count: 1},
      Map.new(metadata)
    )
  end

  @spec workflow_action(atom() | String.t(), :accepted | :rejected, keyword()) :: :ok
  def workflow_action(action, outcome, opts \\ []) do
    action = action |> to_string() |> String.replace(" ", "_")
    metadata = workflow_metadata(action, outcome, opts)

    Logger.log(
      log_level(outcome),
      "api_workflow_#{action}_#{outcome}",
      Enum.into(metadata, [])
    )

    Observability.emit(
      [:api, :workflow, :audit],
      %{count: 1},
      Map.new(metadata)
    )
  end

  defp metadata(action, outcome, opts) do
    opts
    |> Enum.into(%{})
    |> Map.take([
      :account_id,
      :job_id,
      :mode,
      :permission,
      :projection,
      :reason,
      :request_id,
      :tenant_id
    ])
    |> Enum.map(fn {key, value} -> {key, stringify(value)} end)
    |> Keyword.new()
    |> Keyword.put(:api_action, Atom.to_string(action))
    |> Keyword.put(:outcome, Atom.to_string(outcome))
  end

  defp workflow_metadata(action, outcome, opts) do
    opts
    |> Enum.into(%{})
    |> Map.take([:account_id, :reason, :request_id, :tenant_id, :workflow_id])
    |> Enum.map(fn {key, value} -> {key, stringify(value)} end)
    |> Keyword.new()
    |> Keyword.put(:api_action, action)
    |> Keyword.put(:outcome, Atom.to_string(outcome))
  end

  defp stringify(nil), do: nil
  defp stringify(value) when is_binary(value), do: value
  defp stringify(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify(value), do: inspect(value)

  defp log_level(:accepted), do: :info
  defp log_level(:rejected), do: :warning
end
