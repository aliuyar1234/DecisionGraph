defmodule DecisionGraph.Domain.Validation do
  @moduledoc """
  Semantic validation helpers shared by the BEAM store and later runtime layers.
  """

  alias DecisionGraph.Domain
  alias DecisionGraph.Domain.{ActorRef, CanonicalJson, EventEnvelope, SourceRef}
  alias DecisionGraph.Error

  @forbidden_substrings [
    "Bearer ",
    "xoxb-",
    "xoxp-",
    "xoxa-",
    "xoxr-",
    "sk-",
    "ghp_",
    "gho_",
    "ghu_",
    "ghs_",
    "ghr_",
    "-----BEGIN",
    "-----BEGIN PRIVATE KEY",
    "-----BEGIN RSA PRIVATE KEY",
    "-----BEGIN EC PRIVATE KEY",
    "-----BEGIN OPENSSH PRIVATE KEY",
    "AKIA",
    "ASIA",
    "api_key=",
    "apikey=",
    "api-key:",
    "password=",
    "passwd=",
    "secret=",
    "token="
  ]
  @forbidden_patterns Enum.map(@forbidden_substrings, &{&1, String.downcase(&1)})
  @max_idempotency_key_bytes 200
  @actor_types ["agent", "person", "role", "system"]
  @entity_roles ["primary", "related"]
  @policy_decisions ["allow", "deny", "require_exception"]
  @approval_decisions ["approved", "rejected"]
  @action_statuses ["success", "failure", "partial"]
  @trace_outcomes ["success", "failure", "abandoned"]

  @spec validate_envelope!(EventEnvelope.t()) :: :ok
  def validate_envelope!(%EventEnvelope{} = envelope) do
    validate_required_string!(envelope.event_id, "event_id")
    validate_required_string!(envelope.trace_id, "trace_id")
    validate_required_string!(envelope.event_type, "event_type")
    validate_event_type!(envelope.event_type)
    validate_trace_seq_non_negative!(envelope.trace_seq)
    validate_rfc3339!(envelope.occurred_at, "occurred_at")
    validate_idempotency_key!(envelope.idempotency_key)
    validate_schema_version!(envelope.schema_version)
    validate_tags!(envelope.tags)
    validate_actor!(envelope.actor)
    validate_source!(envelope.source)
    validate_payload_json_safe!(envelope.payload)
    validate_payload_schema!(envelope.event_type, envelope.payload)
    check_event_pii!(envelope)
    :ok
  end

  @spec validate_idempotency_key!(String.t()) :: :ok
  def validate_idempotency_key!(key) when is_binary(key) do
    if key == "" do
      raise Error, code: :invalid_argument, message: "Idempotency key cannot be empty"
    end

    if String.contains?(key, <<0>>) do
      raise Error, code: :invalid_argument, message: "Idempotency key cannot contain null bytes"
    end

    key_bytes = key |> :unicode.characters_to_binary() |> byte_size()

    if key_bytes > @max_idempotency_key_bytes do
      raise Error,
        code: :invalid_argument,
        message:
          "Idempotency key exceeds #{@max_idempotency_key_bytes} bytes (got #{key_bytes} bytes)"
    end

    :ok
  end

  def validate_idempotency_key!(_key) do
    raise Error, code: :invalid_argument, message: "Idempotency key must be a string"
  end

  @spec validate_trace_sequence!(EventEnvelope.t(), non_neg_integer()) :: :ok
  def validate_trace_sequence!(%EventEnvelope{} = envelope, expected_seq) do
    if envelope.trace_seq != expected_seq do
      raise Error,
        code: :event_sequence_invalid,
        message: "Expected trace_seq #{expected_seq}, got #{envelope.trace_seq}",
        details: %{expected_trace_seq: expected_seq}
    end

    if envelope.event_type == "TraceStarted" and envelope.trace_seq != 0 do
      raise Error,
        code: :event_sequence_invalid,
        message: "TraceStarted must have trace_seq=0"
    end

    if envelope.event_type != "TraceStarted" and envelope.trace_seq == 0 do
      raise Error,
        code: :event_sequence_invalid,
        message: "First event must be TraceStarted, got #{envelope.event_type}"
    end

    :ok
  end

  @spec validate_payload_schema!(String.t(), map()) :: :ok
  def validate_payload_schema!(event_type, payload) when is_map(payload) do
    validate_event_type!(event_type)
    validate_payload_for_event!(event_type, payload)

    :ok
  end

  def validate_payload_schema!(_event_type, _payload) do
    raise Error, code: :schema_violation, message: "Payload must be a map"
  end

  @spec validate_payload_json_safe!(map()) :: :ok
  def validate_payload_json_safe!(payload) when is_map(payload) do
    _ = CanonicalJson.canonicalize!(payload)
    :ok
  end

  def validate_payload_json_safe!(_payload) do
    raise Error, code: :invalid_argument, message: "Payload must be a map"
  end

  @spec check_event_pii!(EventEnvelope.t()) :: :ok
  def check_event_pii!(%EventEnvelope{} = envelope) do
    metadata = %{
      "payload" => envelope.payload,
      "tags" => envelope.tags,
      "actor" => %{
        "actor_type" => envelope.actor.actor_type,
        "actor_id" => envelope.actor.actor_id
      },
      "source" => %{
        "producer_id" => envelope.source.producer_id,
        "system" => envelope.source.system,
        "subsystem" => envelope.source.subsystem
      },
      "correlation_id" => envelope.correlation_id,
      "causation_event_id" => envelope.causation_event_id,
      "idempotency_key" => envelope.idempotency_key
    }

    scan_forbidden!(metadata, "$")
    :ok
  end

  defp validate_event_type!(event_type) do
    if event_type in Domain.event_types() do
      :ok
    else
      raise Error, code: :schema_violation, message: "Unknown event_type '#{event_type}'"
    end
  end

  defp validate_trace_seq_non_negative!(trace_seq) when is_integer(trace_seq) and trace_seq >= 0,
    do: :ok

  defp validate_trace_seq_non_negative!(_trace_seq) do
    raise Error, code: :invalid_argument, message: "trace_seq must be a non-negative integer"
  end

  defp validate_required_string!(value, path) when is_binary(value) do
    case String.trim(value) do
      "" ->
        raise Error, code: :schema_violation, message: "Missing or invalid string for '#{path}'"

      normalized ->
        normalized
    end
  end

  defp validate_required_string!(_value, path) do
    raise Error, code: :schema_violation, message: "Missing or invalid string for '#{path}'"
  end

  defp validate_optional_string(nil), do: :ok

  defp validate_optional_string(value) when is_binary(value) do
    _ = String.trim(value)
    :ok
  end

  defp validate_optional_string(_value) do
    raise Error,
      code: :schema_violation,
      message: "Optional string fields must be strings when present"
  end

  defp validate_optional_list(nil), do: :ok
  defp validate_optional_list(value) when is_list(value), do: :ok

  defp validate_optional_list(_value) do
    raise Error,
      code: :schema_violation,
      message: "Optional list fields must be lists when present"
  end

  defp validate_schema_version!(value) when is_integer(value) and value > 0, do: :ok

  defp validate_schema_version!(_value) do
    raise Error, code: :schema_violation, message: "schema_version must be a positive integer"
  end

  defp validate_tags!(tags) when is_list(tags) do
    Enum.each(tags, fn tag -> validate_required_string!(tag, "$.tags[]") end)
    :ok
  end

  defp validate_tags!(_tags) do
    raise Error, code: :schema_violation, message: "tags must be a list of strings"
  end

  defp validate_actor!(%ActorRef{} = actor) do
    validate_required_string!(actor.actor_id, "$.actor.actor_id")
    actor_type = validate_required_string!(actor.actor_type, "$.actor.actor_type")
    require_member!(actor_type, @actor_types, "$.actor.actor_type")
    :ok
  end

  defp validate_actor!(_actor) do
    raise Error, code: :schema_violation, message: "actor must be an ActorRef"
  end

  defp validate_source!(%SourceRef{} = source) do
    validate_required_string!(source.producer_id, "$.source.producer_id")
    validate_required_string!(source.system, "$.source.system")
    validate_optional_string(source.subsystem)
    :ok
  end

  defp validate_source!(_source) do
    raise Error, code: :schema_violation, message: "source must be a SourceRef"
  end

  defp validate_payload_for_event!("TraceStarted", payload),
    do: validate_trace_started_payload!(payload)

  defp validate_payload_for_event!("InputObserved", payload),
    do: validate_input_observed_payload!(payload)

  defp validate_payload_for_event!("EntityObserved", payload),
    do: validate_entity_observed_payload!(payload)

  defp validate_payload_for_event!("PolicyEvaluated", payload),
    do: validate_policy_evaluated_payload!(payload)

  defp validate_payload_for_event!("ExceptionRequested", payload),
    do: validate_exception_requested_payload!(payload)

  defp validate_payload_for_event!("ApprovalRecorded", payload),
    do: validate_approval_recorded_payload!(payload)

  defp validate_payload_for_event!("WorkflowReviewRequested", payload),
    do: validate_workflow_review_requested_payload!(payload)

  defp validate_payload_for_event!("PrecedentCited", payload),
    do: validate_precedent_cited_payload!(payload)

  defp validate_payload_for_event!("ActionProposed", payload),
    do: validate_action_proposed_payload!(payload)

  defp validate_payload_for_event!("ActionCommitted", payload),
    do: validate_action_committed_payload!(payload)

  defp validate_payload_for_event!("TraceFinished", payload),
    do: validate_trace_finished_payload!(payload)

  defp validate_trace_started_payload!(payload) do
    validate_required_string!(fetch_value!(payload, "workflow", "$"), "$.workflow")
    validate_required_string!(fetch_value!(payload, "title", "$"), "$.title")
    primary_entity = require_map!(payload, "primary_entity", "$")

    validate_required_string!(
      fetch_value!(primary_entity, "entity_type", "$.primary_entity"),
      "$.primary_entity.entity_type"
    )

    validate_required_string!(
      fetch_value!(primary_entity, "entity_id", "$.primary_entity"),
      "$.primary_entity.entity_id"
    )
  end

  defp validate_workflow_review_requested_payload!(payload) do
    validate_required_string!(fetch_value!(payload, "template_id", "$"), "$.template_id")
    validate_required_string!(fetch_value!(payload, "workflow_kind", "$"), "$.workflow_kind")
    validate_required_string!(fetch_value!(payload, "title", "$"), "$.title")
    validate_required_string!(fetch_value!(payload, "reason", "$"), "$.reason")
    validate_required_string!(fetch_value!(payload, "priority", "$"), "$.priority")

    assignee = require_map!(payload, "assignee", "$")
    _ = fetch_value(assignee, "account_id")
    _ = fetch_value(assignee, "role")

    subject = require_map!(payload, "subject", "$")

    validate_required_string!(
      fetch_value!(subject, "subject_type", "$.subject"),
      "$.subject.subject_type"
    )

    validate_required_string!(
      fetch_value!(subject, "subject_id", "$.subject"),
      "$.subject.subject_id"
    )

    simulation = require_map!(payload, "simulation", "$")
    _ = fetch_value(simulation, "priority")

    sla_hours = fetch_value!(payload, "sla_hours", "$")

    if not (is_integer(sla_hours) and sla_hours > 0) do
      raise Error, code: :schema_violation, message: "sla_hours must be a positive integer"
    end
  end

  defp validate_input_observed_payload!(payload) do
    validate_required_string!(fetch_value!(payload, "input_id", "$"), "$.input_id")
    source = require_map!(payload, "source", "$")
    validate_required_string!(fetch_value!(source, "system", "$.source"), "$.source.system")

    validate_required_string!(
      fetch_value!(source, "object_type", "$.source"),
      "$.source.object_type"
    )

    validate_required_string!(fetch_value!(source, "object_id", "$.source"), "$.source.object_id")
    require_list!(payload, "facts", "$")
  end

  defp validate_entity_observed_payload!(payload) do
    entity = require_map!(payload, "entity", "$")

    validate_required_string!(
      fetch_value!(entity, "entity_type", "$.entity"),
      "$.entity.entity_type"
    )

    validate_required_string!(fetch_value!(entity, "entity_id", "$.entity"), "$.entity.entity_id")

    role = validate_required_string!(fetch_value!(payload, "role", "$"), "$.role")
    require_member!(role, @entity_roles, "$.role")
    require_list!(payload, "facts", "$")
  end

  defp validate_policy_evaluated_payload!(payload) do
    policy = require_map!(payload, "policy", "$")
    validate_required_string!(fetch_value!(policy, "policy_id", "$.policy"), "$.policy.policy_id")

    validate_required_string!(
      fetch_value!(policy, "policy_version", "$.policy"),
      "$.policy.policy_version"
    )

    require_list!(payload, "inputs", "$")
    decision = validate_required_string!(fetch_value!(payload, "decision", "$"), "$.decision")
    require_member!(decision, @policy_decisions, "$.decision")
  end

  defp validate_exception_requested_payload!(payload) do
    validate_required_string!(fetch_value!(payload, "exception_id", "$"), "$.exception_id")
    policy = require_map!(payload, "policy", "$")
    validate_required_string!(fetch_value!(policy, "policy_id", "$.policy"), "$.policy.policy_id")

    validate_required_string!(
      fetch_value!(policy, "policy_version", "$.policy"),
      "$.policy.policy_version"
    )

    validate_required_string!(fetch_value!(payload, "reason", "$"), "$.reason")
    validate_optional_list(fetch_value(payload, "evidence"))
  end

  defp validate_approval_recorded_payload!(payload) do
    validate_required_string!(fetch_value!(payload, "approval_id", "$"), "$.approval_id")
    subject = require_map!(payload, "subject", "$")

    validate_required_string!(
      fetch_value!(subject, "subject_type", "$.subject"),
      "$.subject.subject_type"
    )

    validate_required_string!(
      fetch_value!(subject, "subject_id", "$.subject"),
      "$.subject.subject_id"
    )

    approver = require_map!(payload, "approver", "$")

    validate_required_string!(
      fetch_value!(approver, "actor_type", "$.approver"),
      "$.approver.actor_type"
    )

    validate_required_string!(
      fetch_value!(approver, "actor_id", "$.approver"),
      "$.approver.actor_id"
    )

    decision = validate_required_string!(fetch_value!(payload, "decision", "$"), "$.decision")
    require_member!(decision, @approval_decisions, "$.decision")
    validate_optional_list(fetch_value(payload, "evidence"))
    validate_optional_string(fetch_value(payload, "reason"))
  end

  defp validate_precedent_cited_payload!(payload) do
    validate_required_string!(fetch_value!(payload, "cited_trace_id", "$"), "$.cited_trace_id")
    validate_required_string!(fetch_value!(payload, "reason", "$"), "$.reason")
    validate_optional_string(fetch_value(payload, "similarity_score"))
  end

  defp validate_action_proposed_payload!(payload) do
    validate_required_string!(fetch_value!(payload, "action_id", "$"), "$.action_id")
    validate_required_string!(fetch_value!(payload, "action_type", "$"), "$.action_type")
    target_entity = require_map!(payload, "target_entity", "$")

    validate_required_string!(
      fetch_value!(target_entity, "entity_type", "$.target_entity"),
      "$.target_entity.entity_type"
    )

    validate_required_string!(
      fetch_value!(target_entity, "entity_id", "$.target_entity"),
      "$.target_entity.entity_id"
    )

    validate_required_string!(fetch_value!(payload, "target_system", "$"), "$.target_system")
    require_list!(payload, "changes", "$")
  end

  defp validate_action_committed_payload!(payload) do
    validate_required_string!(fetch_value!(payload, "action_id", "$"), "$.action_id")
    status = validate_required_string!(fetch_value!(payload, "status", "$"), "$.status")
    require_member!(status, @action_statuses, "$.status")
    validate_optional_string(fetch_value(payload, "external_reference"))
    validate_optional_string(fetch_value(payload, "error"))
  end

  defp validate_trace_finished_payload!(payload) do
    outcome = validate_required_string!(fetch_value!(payload, "outcome", "$"), "$.outcome")
    require_member!(outcome, @trace_outcomes, "$.outcome")
    validate_optional_string(fetch_value(payload, "summary"))
  end

  defp require_member!(value, allowed_values, path) do
    if value in allowed_values do
      :ok
    else
      raise Error, code: :schema_violation, message: "Invalid value '#{value}' for '#{path}'"
    end
  end

  defp require_map!(payload, key, path) do
    case fetch_value(payload, key) do
      value when is_map(value) ->
        value

      _ ->
        raise Error,
          code: :schema_violation,
          message: "Missing or invalid object for '#{path}.#{key}'"
    end
  end

  defp require_list!(payload, key, path) do
    case fetch_value(payload, key) do
      value when is_list(value) ->
        value

      _ ->
        raise Error,
          code: :schema_violation,
          message: "Missing or invalid list for '#{path}.#{key}'"
    end
  end

  defp fetch_value!(payload, key, path) do
    case fetch_value(payload, key) do
      nil ->
        raise Error,
          code: :schema_violation,
          message: "Missing or invalid value for '#{path}.#{key}'"

      value ->
        value
    end
  end

  defp fetch_value(payload, key) when is_map(payload) and is_binary(key) do
    Map.get(payload, key) || fetch_atom_value(payload, key)
  end

  defp fetch_atom_value(payload, key) do
    atom_key = String.to_existing_atom(key)
    Map.get(payload, atom_key)
  rescue
    ArgumentError -> nil
  end

  defp validate_rfc3339!(value, field_name) when is_binary(value) do
    case DateTime.from_iso8601(String.trim(value)) do
      {:ok, _datetime, _offset} ->
        :ok

      _ ->
        raise Error,
          code: :invalid_argument,
          message: "#{field_name} must be an RFC3339 timestamp"
    end
  end

  defp validate_rfc3339!(_value, field_name) do
    raise Error, code: :invalid_argument, message: "#{field_name} must be an RFC3339 timestamp"
  end

  defp scan_forbidden!(value, path) when is_binary(value) do
    case find_forbidden_pattern(String.downcase(value)) do
      nil ->
        :ok

      forbidden ->
        raise Error,
          code: :pii_policy_violation,
          message: "Forbidden content '#{forbidden}' found at '#{path}'"
    end
  end

  defp scan_forbidden!(value, path) when is_map(value) do
    Enum.each(value, fn {key, item} -> scan_forbidden!(item, "#{path}.#{key}") end)
  end

  defp scan_forbidden!(value, path) when is_list(value) do
    Enum.with_index(value)
    |> Enum.each(fn {item, index} -> scan_forbidden!(item, "#{path}[#{index}]") end)
  end

  defp scan_forbidden!(_value, _path), do: :ok

  defp find_forbidden_pattern(lowered) do
    Enum.find_value(@forbidden_patterns, fn {original, lowered_pattern} ->
      if String.contains?(lowered, lowered_pattern), do: original
    end)
  end
end
