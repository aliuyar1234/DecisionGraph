defmodule DecisionGraph.Api.ConsoleSupport do
  @moduledoc false

  alias DecisionGraph.Api
  alias DecisionGraph.Api.{Errors, Serialization, ServiceAccount}

  @spec operator_actor_result() :: {:ok, ServiceAccount.t()} | {:error, Exception.t()}
  def operator_actor_result do
    case Api.operator_console_actor() do
      %ServiceAccount{} = actor ->
        {:ok, actor}

      nil ->
        {:error,
         Errors.forbidden(
           "Replay controls are disabled until operator_console_account_id or operator_console_actor is configured"
         )}
    end
  end

  @spec operator_request_id(String.t()) :: String.t()
  def operator_request_id(prefix) do
    "#{prefix}-console-#{System.unique_integer([:positive])}"
  end

  @spec maybe_add_alert(list(), boolean(), String.t(), String.t(), String.t()) :: list()
  def maybe_add_alert(alerts, false, _kind, _title, _detail), do: alerts

  def maybe_add_alert(alerts, true, kind, title, detail) do
    alerts ++ [%{"detail" => detail, "kind" => kind, "title" => title}]
  end

  @spec first_recent_trace_id(map()) :: String.t() | nil
  def first_recent_trace_id(%{items: [%{"trace_id" => trace_id} | _rest]}), do: trace_id
  def first_recent_trace_id(_section), do: nil

  @spec first_workflow_id(map(), String.t() | nil) :: String.t() | nil
  def first_workflow_id(%{data: %{"items" => items}}, trace_id) when is_list(items) do
    items
    |> Enum.find(fn item ->
      Map.get(item, "trace_id") == trace_id or
        Map.get(item, "status") in ["requested", "changes_requested"]
    end)
    |> case do
      %{"workflow_id" => workflow_id} -> workflow_id
      _other -> nil
    end
  end

  def first_workflow_id(_section, _trace_id), do: nil

  @spec normalize_positive_limit(term(), pos_integer(), pos_integer()) :: pos_integer()
  def normalize_positive_limit(limit, _default, max) when is_integer(limit) and limit > 0 do
    min(limit, max)
  end

  def normalize_positive_limit(limit, default, max) do
    limit
    |> to_string()
    |> Integer.parse()
    |> case do
      {value, ""} when value > 0 -> min(value, max)
      _other -> default
    end
  end

  @spec normalize_recent_limit(term(), pos_integer()) :: pos_integer()
  def normalize_recent_limit(limit, default), do: normalize_positive_limit(limit, default, 24)

  @spec normalize_event_limit(term(), pos_integer()) :: pos_integer()
  def normalize_event_limit(limit, default), do: normalize_positive_limit(limit, default, 24)

  @spec normalize_run_limit(term(), pos_integer()) :: pos_integer()
  def normalize_run_limit(limit, default), do: normalize_positive_limit(limit, default, 12)

  @spec normalize_failure_limit(term(), pos_integer()) :: pos_integer()
  def normalize_failure_limit(limit, default), do: normalize_positive_limit(limit, default, 10)

  @spec normalize_tenant_id(term()) :: String.t()
  def normalize_tenant_id(value) do
    value
    |> normalize_optional_string()
    |> case do
      nil -> "default"
      tenant_id -> tenant_id
    end
  end

  @spec normalize_optional_string(term() | nil) :: String.t() | nil
  def normalize_optional_string(nil), do: nil

  def normalize_optional_string(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  @spec field_integer(map(), String.t()) :: integer()
  def field_integer(map, key) do
    case Map.get(map, key) do
      value when is_integer(value) -> value
      _other -> 0
    end
  end

  @spec truthy_field?(map(), String.t()) :: boolean()
  def truthy_field?(map, key), do: Map.get(map, key) in [true, "true"]

  @spec payload_value(term(), list()) :: term()
  def payload_value(nil, _path), do: nil
  def payload_value(value, []), do: value

  def payload_value(map, [key | rest]) when is_map(map) do
    atom_key =
      if is_binary(key) do
        try do
          String.to_existing_atom(key)
        rescue
          ArgumentError -> nil
        end
      end

    next_value =
      cond do
        Map.has_key?(map, key) -> Map.get(map, key)
        atom_key && Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
        true -> nil
      end

    payload_value(next_value, rest)
  end

  def payload_value(_value, _path), do: nil

  @spec blank?(term()) :: boolean()
  def blank?(nil), do: true
  def blank?(value) when is_binary(value), do: String.trim(value) == ""
  def blank?(_value), do: false

  @spec entity_label(map()) :: String.t()
  def entity_label(summary) do
    [
      Map.get(summary, "primary_entity_system"),
      Map.get(summary, "primary_entity_type"),
      Map.get(summary, "primary_entity_id")
    ]
    |> Enum.reject(&blank?/1)
    |> Enum.join(":")
    |> case do
      "" -> "unknown"
      label -> label
    end
  end

  @spec serialize_data(term()) :: term()
  def serialize_data(value) do
    value
    |> Serialization.serialize()
    |> stringify_keys()
  end

  @spec precedent_query(map(), map()) :: map()
  def precedent_query(summary, policy) do
    %{
      "entity_id" => Map.get(summary, "primary_entity_id"),
      "entity_type" => Map.get(summary, "primary_entity_type"),
      "limit" => 6,
      "outcome" => Map.get(summary, "outcome"),
      "policy_id" => Map.get(policy, "policy_id"),
      "policy_version" => Map.get(policy, "policy_version")
    }
    |> Enum.reject(fn {_key, value} -> blank?(value) end)
    |> Map.new()
  end

  @spec trace_policy(map()) :: map()
  def trace_policy(trace) do
    trace
    |> get_in([:data, "events"])
    |> trace_policy_from_events()
  end

  @spec investigator_handoff(map()) :: String.t() | nil
  def investigator_handoff(%{"events" => events, "summary" => summary}) when is_list(events) do
    approval = latest_event(events, "ApprovalRecorded")
    exception = latest_event(events, "ExceptionRequested")

    [
      "trace=#{Map.get(summary, "trace_id", "unknown")}",
      "workflow=#{Map.get(summary, "workflow", "unknown")}",
      "entity=#{entity_label(summary)}",
      "outcome=#{Map.get(summary, "outcome", "pending")}",
      "exception_id=#{payload_value(exception, ["exception_id"]) || "none"}",
      "approval=#{payload_value(approval, ["decision"]) || payload_value(approval, ["status"]) || "pending"}",
      "policy=#{trace_policy_from_events(events) |> Map.get("policy_id", "unknown")}"
    ]
    |> Enum.join("\n")
  end

  def investigator_handoff(_trace), do: nil

  @spec policy_event_summary(map()) :: String.t()
  def policy_event_summary(event) when is_map(event) do
    payload = Map.get(event, "payload") || %{}

    case Map.get(event, "event_type") do
      "PolicyEvaluated" -> policy_decision_summary(payload)
      "ExceptionRequested" -> payload_value(payload, ["exception_id"]) || "Exception requested"
      "ApprovalRecorded" -> approval_decision_summary(payload)
      "ActionProposed" -> payload_value(payload, ["action_id"]) || "Action proposed"
      "ActionCommitted" -> payload_value(payload, ["action_id"]) || "Action committed"
      "TraceFinished" -> payload_value(payload, ["outcome"]) || "Trace finished"
      _other -> "Event recorded"
    end
  end

  @spec latest_event(list(), String.t()) :: map() | nil
  def latest_event(events, event_type) when is_list(events) do
    events
    |> Enum.reverse()
    |> Enum.find(&(Map.get(&1, "event_type") == event_type))
  end

  def latest_event(_events, _event_type), do: nil

  defp trace_policy_from_events(events) when is_list(events) do
    events
    |> latest_event("PolicyEvaluated")
    |> payload_value(["policy"])
    |> case do
      policy when is_map(policy) -> serialize_data(policy)
      _other -> %{}
    end
  end

  defp trace_policy_from_events(_events), do: %{}

  defp policy_decision_summary(payload) do
    payload_value(payload, ["decision"]) ||
      payload_value(payload, ["explanation", "summary"]) ||
      "Policy evaluated"
  end

  defp approval_decision_summary(payload) do
    payload_value(payload, ["decision"]) ||
      payload_value(payload, ["status"]) ||
      "Approval recorded"
  end

  defp stringify_keys(%_{} = struct), do: struct |> Map.from_struct() |> stringify_keys()

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      normalized_key =
        case key do
          atom when is_atom(atom) -> Atom.to_string(atom)
          other -> other
        end

      {normalized_key, stringify_keys(value)}
    end)
  end

  defp stringify_keys(list) when is_list(list), do: Enum.map(list, &stringify_keys/1)
  defp stringify_keys(value), do: value
end
