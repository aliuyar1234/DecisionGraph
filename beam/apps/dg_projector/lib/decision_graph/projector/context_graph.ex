defmodule DecisionGraph.Projector.ContextGraph do
  @moduledoc false

  alias DecisionGraph.Domain.StoredEvent
  alias DecisionGraph.Projector.{Edge, Node}

  @node_type_trace "trace"
  @node_type_entity "entity"
  @node_type_input "input"
  @node_type_policy "policy"
  @node_type_exception "exception"
  @node_type_action "action"
  @node_type_actor "actor"

  @edge_type_trace_involves_entity "trace_involves_entity"
  @edge_type_trace_observed_input "trace_observed_input"
  @edge_type_trace_evaluated_policy "trace_evaluated_policy"
  @edge_type_trace_requested_exception "trace_requested_exception"
  @edge_type_exception_approved_by "exception_approved_by"
  @edge_type_trace_cited_precedent "trace_cited_precedent"
  @edge_type_trace_proposed_action "trace_proposed_action"
  @edge_type_trace_committed_action "trace_committed_action"
  @edge_type_action_targets_entity "action_targets_entity"

  defmodule GraphEmission do
    @moduledoc false

    @enforce_keys [:nodes, :edges]
    defstruct [:nodes, :edges]

    @type t :: %__MODULE__{
            nodes: [Node.t()],
            edges: [Edge.t()]
          }
  end

  @spec emit(StoredEvent.t()) :: GraphEmission.t()
  def emit(%StoredEvent{} = event) do
    case event.event_type do
      "TraceStarted" -> emit_trace_started(event)
      "InputObserved" -> emit_input_observed(event)
      "EntityObserved" -> emit_entity_observed(event)
      "PolicyEvaluated" -> emit_policy_evaluated(event)
      "ExceptionRequested" -> emit_exception_requested(event)
      "ApprovalRecorded" -> emit_approval_recorded(event)
      "PrecedentCited" -> emit_precedent_cited(event)
      "ActionProposed" -> emit_action_proposed(event)
      "ActionCommitted" -> emit_action_committed(event)
      "TraceFinished" -> emit_trace_finished(event)
      _ -> %GraphEmission{nodes: [], edges: []}
    end
  end

  @spec make_node_id(String.t(), String.t()) :: String.t()
  def make_node_id(node_type, identifier), do: "#{node_type}:#{identifier}"

  @spec make_edge_id(String.t(), String.t(), String.t(), String.t()) :: String.t()
  def make_edge_id(edge_type, from_node_id, to_node_id, event_id) do
    "#{edge_type}:#{from_node_id}:#{to_node_id}:#{event_id}"
  end

  defp emit_trace_started(event) do
    trace_node_id = make_node_id(@node_type_trace, event.trace_id)

    actor_node_id =
      make_node_id(@node_type_actor, "#{event.actor.actor_type}:#{event.actor.actor_id}")

    nodes = [
      node(trace_node_id, @node_type_trace, event),
      node(actor_node_id, @node_type_actor, event)
    ]

    case fetch(event.payload, "primary_entity") do
      entity when is_map(entity) ->
        entity_identifier =
          "#{fetch(entity, "entity_type", "unknown")}:#{fetch(entity, "entity_id", "unknown")}"

        entity_node_id = make_node_id(@node_type_entity, entity_identifier)

        %GraphEmission{
          nodes: nodes ++ [node(entity_node_id, @node_type_entity, event)],
          edges: [
            edge(
              @edge_type_trace_involves_entity,
              trace_node_id,
              entity_node_id,
              event
            )
          ]
        }

      _ ->
        %GraphEmission{nodes: nodes, edges: []}
    end
  end

  defp emit_input_observed(event) do
    input_id = fetch(event.payload, "input_id", event.event_id)
    trace_node_id = make_node_id(@node_type_trace, event.trace_id)
    input_node_id = make_node_id(@node_type_input, input_id)

    %GraphEmission{
      nodes: [node(input_node_id, @node_type_input, event)],
      edges: [edge(@edge_type_trace_observed_input, trace_node_id, input_node_id, event)]
    }
  end

  defp emit_entity_observed(event) do
    entity = fetch(event.payload, "entity", %{})

    entity_identifier =
      "#{fetch(entity, "entity_type", "unknown")}:#{fetch(entity, "entity_id", "unknown")}"

    trace_node_id = make_node_id(@node_type_trace, event.trace_id)
    entity_node_id = make_node_id(@node_type_entity, entity_identifier)

    %GraphEmission{
      nodes: [node(entity_node_id, @node_type_entity, event)],
      edges: [edge(@edge_type_trace_involves_entity, trace_node_id, entity_node_id, event)]
    }
  end

  defp emit_policy_evaluated(event) do
    policy = fetch(event.payload, "policy", %{})
    policy_id = fetch(policy, "policy_id") || "unknown:#{event.event_id}"
    policy_version = fetch(policy, "policy_version", "")

    policy_identifier =
      if policy_version == "", do: policy_id, else: "#{policy_id}:#{policy_version}"

    trace_node_id = make_node_id(@node_type_trace, event.trace_id)
    policy_node_id = make_node_id(@node_type_policy, policy_identifier)

    %GraphEmission{
      nodes: [node(policy_node_id, @node_type_policy, event)],
      edges: [edge(@edge_type_trace_evaluated_policy, trace_node_id, policy_node_id, event)]
    }
  end

  defp emit_exception_requested(event) do
    exception_id = fetch(event.payload, "exception_id", event.event_id)
    trace_node_id = make_node_id(@node_type_trace, event.trace_id)
    exception_node_id = make_node_id(@node_type_exception, exception_id)

    %GraphEmission{
      nodes: [node(exception_node_id, @node_type_exception, event)],
      edges: [
        edge(@edge_type_trace_requested_exception, trace_node_id, exception_node_id, event)
      ]
    }
  end

  defp emit_approval_recorded(event) do
    subject = fetch(event.payload, "subject", %{})
    approver = fetch(event.payload, "approver", %{})

    approver_id =
      "#{fetch(approver, "actor_type", "person")}:#{fetch(approver, "actor_id", "unknown")}"

    actor_node_id = make_node_id(@node_type_actor, approver_id)
    nodes = [node(actor_node_id, @node_type_actor, event)]

    if fetch(subject, "subject_type") == "exception" and present?(fetch(subject, "subject_id")) do
      exception_node_id = make_node_id(@node_type_exception, fetch(subject, "subject_id"))

      %GraphEmission{
        nodes: nodes,
        edges: [edge(@edge_type_exception_approved_by, exception_node_id, actor_node_id, event)]
      }
    else
      %GraphEmission{nodes: nodes, edges: []}
    end
  end

  defp emit_precedent_cited(event) do
    cited_trace_id = fetch(event.payload, "cited_trace_id")

    if present?(cited_trace_id) do
      trace_node_id = make_node_id(@node_type_trace, event.trace_id)
      cited_trace_node_id = make_node_id(@node_type_trace, cited_trace_id)

      %GraphEmission{
        nodes: [],
        edges: [edge(@edge_type_trace_cited_precedent, trace_node_id, cited_trace_node_id, event)]
      }
    else
      %GraphEmission{nodes: [], edges: []}
    end
  end

  defp emit_action_proposed(event) do
    action_id = fetch(event.payload, "action_id", event.event_id)
    trace_node_id = make_node_id(@node_type_trace, event.trace_id)
    action_node_id = make_node_id(@node_type_action, action_id)

    edges = [edge(@edge_type_trace_proposed_action, trace_node_id, action_node_id, event)]

    edges =
      case fetch(event.payload, "target_entity") do
        entity when is_map(entity) ->
          entity_identifier =
            "#{fetch(entity, "entity_type", "unknown")}:#{fetch(entity, "entity_id", "unknown")}"

          entity_node_id = make_node_id(@node_type_entity, entity_identifier)
          edges ++ [edge(@edge_type_action_targets_entity, action_node_id, entity_node_id, event)]

        _ ->
          edges
      end

    %GraphEmission{
      nodes: [node(action_node_id, @node_type_action, event)],
      edges: edges
    }
  end

  defp emit_action_committed(event) do
    action_id = fetch(event.payload, "action_id")

    if present?(action_id) do
      trace_node_id = make_node_id(@node_type_trace, event.trace_id)
      action_node_id = make_node_id(@node_type_action, action_id)

      %GraphEmission{
        nodes: [],
        edges: [edge(@edge_type_trace_committed_action, trace_node_id, action_node_id, event)]
      }
    else
      %GraphEmission{nodes: [], edges: []}
    end
  end

  defp emit_trace_finished(_event), do: %GraphEmission{nodes: [], edges: []}

  defp node(node_id, node_type, event) do
    %Node{
      node_id: node_id,
      node_type: node_type,
      trace_id: event.trace_id,
      log_seq: event.log_seq,
      created_at: event.occurred_at,
      attrs: %{}
    }
  end

  defp edge(edge_type, from_node_id, to_node_id, event) do
    %Edge{
      edge_id: make_edge_id(edge_type, from_node_id, to_node_id, event.event_id),
      edge_type: edge_type,
      from_node_id: from_node_id,
      to_node_id: to_node_id,
      trace_id: event.trace_id,
      log_seq: event.log_seq,
      created_at: event.occurred_at,
      attrs: %{}
    }
  end

  defp fetch(map, key, default \\ nil) when is_map(map) do
    atom_key =
      try do
        String.to_existing_atom(key)
      rescue
        ArgumentError -> nil
      end

    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      atom_key && Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      true -> default
    end
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)
end
