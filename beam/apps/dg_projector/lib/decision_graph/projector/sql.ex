defmodule DecisionGraph.Projector.SQL do
  @moduledoc false

  alias DecisionGraph.Store
  alias DecisionGraph.Store.Repo
  alias Ecto.Adapters.SQL

  @spec query_all!(String.t(), [term()]) :: [map()]
  def query_all!(sql, params \\ []) do
    ensure_repo_started!()

    SQL.query!(Repo, sql, params)
    |> result_to_rows()
  end

  @spec query_one!(String.t(), [term()]) :: map()
  def query_one!(sql, params \\ []) do
    case query_all!(sql, params) do
      [row | _rest] -> row
      [] -> %{}
    end
  end

  @spec execute!(String.t(), [term()]) :: :ok
  def execute!(sql, params \\ []) do
    ensure_repo_started!()
    _ = SQL.query!(Repo, sql, params)
    :ok
  end

  @spec transaction((-> term())) :: {:ok, term()} | {:error, term()}
  def transaction(fun) when is_function(fun, 0) do
    ensure_repo_started!()
    Repo.transaction(fun)
  end

  @spec now_rfc3339(DateTime.t()) :: String.t()
  def now_rfc3339(datetime \\ DateTime.utc_now()) do
    datetime
    |> DateTime.truncate(:microsecond)
    |> format_rfc3339()
  end

  defp format_rfc3339(%DateTime{} = datetime) do
    base = Calendar.strftime(datetime, "%Y-%m-%dT%H:%M:%S")

    case elem(datetime.microsecond, 0) do
      0 ->
        base <> "Z"

      microsecond ->
        fraction =
          microsecond
          |> Integer.to_string()
          |> String.pad_leading(6, "0")
          |> String.trim_trailing("0")

        base <> "." <> fraction <> "Z"
    end
  end

  defp ensure_repo_started!, do: Store.ensure_repo_started!()

  defp result_to_rows(%{columns: columns, rows: rows}) do
    columns = columns || []
    rows = rows || []

    Enum.map(rows, fn values ->
      columns
      |> Enum.zip(values)
      |> Map.new()
    end)
  end
end
