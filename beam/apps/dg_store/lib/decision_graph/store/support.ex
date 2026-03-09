defmodule DecisionGraph.Store.Support do
  @moduledoc false

  alias DecisionGraph.Domain.StoredEvent
  alias DecisionGraph.Error
  alias DecisionGraph.Store.Repo
  alias Ecto.Adapters.SQL

  @spec row_to_stored_event(map()) :: StoredEvent.t()
  def row_to_stored_event(row) do
    tags = row["tags_json"] |> Jason.decode!()
    payload = row["payload_json"] |> Jason.decode!()

    StoredEvent.new(%{
      actor: %{
        actor_id: row["actor_id"],
        actor_type: row["actor_type"]
      },
      causation_event_id: row["causation_event_id"],
      correlation_id: row["correlation_id"],
      event_id: row["event_id"],
      event_type: row["event_type"],
      idempotency_key: row["idempotency_key"],
      log_seq: row["log_seq"],
      occurred_at: row["occurred_at"],
      payload: payload,
      payload_hash: row["payload_hash"],
      recorded_at: row["recorded_at"],
      schema_version: row["schema_version"],
      source: %{
        producer_id: row["producer_id"],
        subsystem: row["source_subsystem"],
        system: row["source_system"]
      },
      tags: tags,
      tenant_id: row["tenant_id"],
      trace_id: row["trace_id"],
      trace_seq: row["trace_seq"]
    })
  end

  @spec query_one_row!(String.t(), list()) :: map()
  def query_one_row!(sql, params) do
    case query_all_rows!(sql, params) do
      [row | _rest] -> row
      [] -> %{}
    end
  end

  @spec query_all_rows!(String.t(), list()) :: [map()]
  def query_all_rows!(sql, params) do
    SQL.query!(Repo, normalize_sql_placeholders(sql), params)
    |> result_to_rows()
  end

  @spec append_metadata(String.t(), map(), keyword()) :: map()
  def append_metadata(tenant_id, envelope, opts) do
    %{
      event_type: envelope.event_type,
      producer_id: envelope.source.producer_id,
      request_id: Keyword.get(opts, :request_id),
      tenant_id: tenant_id,
      trace_id: envelope.trace_id
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  @spec optional_clause(term() | nil, String.t()) :: {String.t(), term()} | nil
  def optional_clause(nil, _sql), do: nil
  def optional_clause(value, sql), do: {sql, value}

  @spec collect_clauses(list(), String.t() | nil) :: {[String.t()], list()}
  def collect_clauses(clauses, default_clause \\ nil) do
    {clauses, params} =
      clauses
      |> Enum.reject(&is_nil/1)
      |> Enum.map_reduce([], fn {sql, value}, params ->
        {String.replace(sql, "?", "$#{length(params) + 1}"), params ++ [value]}
      end)

    clauses =
      case {clauses, default_clause} do
        {[], nil} -> []
        {[], clause} -> [clause]
        {resolved_clauses, _default_clause} -> resolved_clauses
      end

    {clauses, params}
  end

  @spec maybe_limit_sql(pos_integer() | nil, non_neg_integer()) :: String.t()
  def maybe_limit_sql(nil, _param_count), do: ""
  def maybe_limit_sql(_limit, param_count), do: " LIMIT $#{param_count + 1}"

  @spec append_limit_param(list(), pos_integer() | nil) :: list()
  def append_limit_param(params, nil), do: params
  def append_limit_param(params, limit), do: params ++ [limit]

  @spec normalize_optional_tenant_id(term() | nil) :: String.t() | nil
  def normalize_optional_tenant_id(nil), do: nil
  def normalize_optional_tenant_id(tenant_id), do: normalize_tenant_id(tenant_id)

  @spec normalize_tenant_id(term()) :: String.t()
  def normalize_tenant_id(tenant_id) when is_binary(tenant_id) do
    case String.trim(tenant_id) do
      "" -> raise Error, code: :invalid_argument, message: "tenant_id cannot be empty"
      normalized -> normalized
    end
  end

  def normalize_tenant_id(tenant_id) do
    tenant_id
    |> to_string()
    |> normalize_tenant_id()
  end

  @spec normalize_optional_string(term() | nil) :: String.t() | nil
  def normalize_optional_string(nil), do: nil

  def normalize_optional_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      normalized -> normalized
    end
  end

  def normalize_optional_string(value), do: value |> to_string() |> normalize_optional_string()

  @spec normalize_positive_optional(term() | nil, atom()) :: pos_integer() | nil
  def normalize_positive_optional(nil, _field), do: nil
  def normalize_positive_optional(value, _field) when is_integer(value) and value > 0, do: value

  def normalize_positive_optional(_value, field) do
    raise Error, code: :invalid_argument, message: "#{field} must be a positive integer"
  end

  @spec normalize_non_negative_optional(term() | nil, atom()) :: non_neg_integer() | nil
  def normalize_non_negative_optional(nil, _field), do: nil

  def normalize_non_negative_optional(value, _field)
      when is_integer(value) and value >= 0,
      do: value

  def normalize_non_negative_optional(_value, field) do
    raise Error, code: :invalid_argument, message: "#{field} must be a non-negative integer"
  end

  @spec normalize_rfc3339_optional(term() | nil, atom()) :: String.t() | nil
  def normalize_rfc3339_optional(nil, _field), do: nil

  def normalize_rfc3339_optional(value, field) when is_binary(value) do
    case DateTime.from_iso8601(String.trim(value)) do
      {:ok, datetime, _offset} ->
        now_rfc3339(datetime)

      {:error, _reason} ->
        raise Error, code: :invalid_argument, message: "#{field} must be an RFC3339 timestamp"
    end
  end

  def normalize_rfc3339_optional(_value, field) do
    raise Error, code: :invalid_argument, message: "#{field} must be an RFC3339 timestamp"
  end

  @spec normalize_projection_name(atom() | String.t(), [atom()]) :: String.t()
  def normalize_projection_name(value, projection_names) when is_atom(value) do
    if value in projection_names do
      Atom.to_string(value)
    else
      raise Error, code: :invalid_argument, message: "Unknown projection '#{inspect(value)}'"
    end
  end

  def normalize_projection_name(value, projection_names) when is_binary(value) do
    normalized = String.trim(value)

    if normalized in Enum.map(projection_names, &Atom.to_string/1) do
      normalized
    else
      raise Error, code: :invalid_argument, message: "Unknown projection '#{value}'"
    end
  end

  def normalize_projection_name(value, projection_names) do
    value
    |> to_string()
    |> normalize_projection_name(projection_names)
  end

  @spec postgres_detail(map(), atom()) :: term()
  def postgres_detail(error, key) do
    error
    |> Map.get(:postgres, %{})
    |> Map.get(key)
  end

  @spec error(atom(), String.t(), map()) :: Exception.t()
  def error(code, message, details \\ %{}) do
    Error.exception(code: code, message: message, details: details)
  end

  @spec now_rfc3339(DateTime.t()) :: String.t()
  def now_rfc3339(datetime \\ DateTime.utc_now()) do
    datetime
    |> DateTime.truncate(:microsecond)
    |> format_rfc3339()
  end

  @spec validate_log_seq_bounds!(non_neg_integer() | nil, non_neg_integer() | nil) :: :ok
  def validate_log_seq_bounds!(nil, _until_log_seq), do: :ok
  def validate_log_seq_bounds!(_since_log_seq, nil), do: :ok

  def validate_log_seq_bounds!(since_log_seq, until_log_seq)
      when since_log_seq <= until_log_seq do
    :ok
  end

  def validate_log_seq_bounds!(_since_log_seq, _until_log_seq) do
    raise Error,
      code: :invalid_argument,
      message: "since_log_seq must be <= until_log_seq"
  end

  @spec validate_occurred_at_bounds!(String.t() | nil, String.t() | nil) :: :ok
  def validate_occurred_at_bounds!(nil, _until_occurred_at), do: :ok
  def validate_occurred_at_bounds!(_since_occurred_at, nil), do: :ok

  def validate_occurred_at_bounds!(since_occurred_at, until_occurred_at)
      when since_occurred_at <= until_occurred_at do
    :ok
  end

  def validate_occurred_at_bounds!(_since_occurred_at, _until_occurred_at) do
    raise Error,
      code: :invalid_argument,
      message: "since_occurred_at must be <= until_occurred_at"
  end

  @spec normalize_sql_placeholders(String.t()) :: String.t()
  def normalize_sql_placeholders(sql) do
    normalize_sql_placeholders(sql, 1, "")
  end

  defp result_to_rows(%{columns: columns, rows: rows}) do
    columns = columns || []
    rows = rows || []

    Enum.map(rows, fn values ->
      columns
      |> Enum.zip(values)
      |> Map.new()
    end)
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

  defp normalize_sql_placeholders(<<>>, _index, acc), do: acc

  defp normalize_sql_placeholders(<<??, rest::binary>>, index, acc) do
    normalize_sql_placeholders(rest, index + 1, acc <> "$" <> Integer.to_string(index))
  end

  defp normalize_sql_placeholders(<<char::utf8, rest::binary>>, index, acc) do
    normalize_sql_placeholders(rest, index, acc <> <<char::utf8>>)
  end
end
