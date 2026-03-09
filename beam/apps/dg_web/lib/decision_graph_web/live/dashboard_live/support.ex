defmodule DecisionGraphWeb.DashboardLive.Support do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]

  @replay_projections ["trace_summary", "context_graph", "precedent_index", "all"]

  def queue_snapshot_refresh(socket) do
    send(
      self(),
      {:load_snapshot, socket.assigns.tenant_id, socket.assigns.trace_id,
       socket.assigns.workflow_id}
    )

    assign(socket, :loading, true)
  end

  def snapshot_for(tenant_id, trace_id, workflow_id) do
    DecisionGraph.Api.service(:console).snapshot(
      tenant_id: tenant_id,
      trace_id: trace_id,
      workflow_id: workflow_id
    )
  end

  def default_replay_form do
    %{
      "confirm_text" => "",
      "mode" => "catch_up",
      "projection" => "trace_summary",
      "reason" => ""
    }
  end

  def default_workflow_form do
    %{
      "action" => "approve",
      "assigned_account_id" => "",
      "assigned_role" => "",
      "confirm_text" => "",
      "note" => "",
      "reason" => ""
    }
  end

  def default_review_form do
    %{
      "reason" => "",
      "template_id" => "incident_triage"
    }
  end

  def replay_form_from_params(params, fallback) do
    %{
      "confirm_text" =>
        string_value(params, "confirm_text", replay_form_value(fallback, "confirm_text")),
      "mode" =>
        normalize_replay_mode(string_value(params, "mode", replay_form_value(fallback, "mode"))),
      "projection" =>
        normalize_replay_projection(
          string_value(params, "projection", replay_form_value(fallback, "projection"))
        ),
      "reason" => string_value(params, "reason", replay_form_value(fallback, "reason"))
    }
  end

  def replay_request_attrs(form, trace_id) do
    %{
      "metadata" =>
        %{}
        |> maybe_put("selected_trace_id", trace_id)
        |> Map.put("requested_from", "operator_console"),
      "mode" => replay_form_value(form, "mode"),
      "projection" => replay_form_value(form, "projection"),
      "reason" => replay_form_value(form, "reason")
    }
  end

  def reset_replay_form(form) do
    form
    |> Map.put("confirm_text", "")
    |> Map.put("reason", "")
  end

  def review_form_from_params(params, fallback) do
    %{
      "reason" => string_value(params, "reason", review_form_value(fallback, "reason")),
      "template_id" =>
        string_value(params, "template_id", review_form_value(fallback, "template_id"))
    }
  end

  def review_request_attrs(form) do
    %{
      "reason" => review_form_value(form, "reason"),
      "template_id" => review_form_value(form, "template_id")
    }
  end

  def reset_review_form(form) do
    form
    |> Map.put("reason", "")
  end

  def workflow_form_from_params(params, fallback) do
    %{
      "action" => string_value(params, "action", workflow_form_value(fallback, "action")),
      "assigned_account_id" =>
        string_value(
          params,
          "assigned_account_id",
          workflow_form_value(fallback, "assigned_account_id")
        ),
      "assigned_role" =>
        string_value(params, "assigned_role", workflow_form_value(fallback, "assigned_role")),
      "confirm_text" =>
        string_value(params, "confirm_text", workflow_form_value(fallback, "confirm_text")),
      "note" => string_value(params, "note", workflow_form_value(fallback, "note")),
      "reason" => string_value(params, "reason", workflow_form_value(fallback, "reason"))
    }
  end

  def workflow_request_attrs(form) do
    %{}
    |> Map.put("action", workflow_form_value(form, "action"))
    |> maybe_put(
      "assigned_account_id",
      blank_to_nil(workflow_form_value(form, "assigned_account_id"))
    )
    |> maybe_put("assigned_role", blank_to_nil(workflow_form_value(form, "assigned_role")))
    |> maybe_put("confirm_text", blank_to_nil(workflow_form_value(form, "confirm_text")))
    |> maybe_put("note", blank_to_nil(workflow_form_value(form, "note")))
    |> maybe_put("reason", blank_to_nil(workflow_form_value(form, "reason")))
  end

  def reset_workflow_form(form) do
    form
    |> Map.put("assigned_account_id", "")
    |> Map.put("assigned_role", "")
    |> Map.put("confirm_text", "")
    |> Map.put("note", "")
    |> Map.put("reason", "")
  end

  def validate_replay_form(form, snapshot) do
    cond do
      not console_actions_enabled?(snapshot) ->
        {:error, get_in(snapshot, [:console_controls, :error]) || "Replay actions are disabled."}

      replay_form_value(form, "mode") == "rebuild" and not console_can_rebuild?(snapshot) ->
        {:error, "The configured console actor cannot request rebuild operations."}

      String.trim(replay_form_value(form, "reason")) == "" ->
        {:error, "Replay reason is required."}

      String.trim(replay_form_value(form, "confirm_text")) != replay_confirmation_phrase(form) ->
        {:error, "Type the exact confirmation phrase before queueing the replay."}

      true ->
        :ok
    end
  end

  def validate_workflow_form(form, snapshot) do
    action = workflow_form_value(form, "action")

    cond do
      not workflow_actions_enabled?(snapshot) ->
        {:error, "The configured console actor cannot perform workflow actions."}

      action in ["approve", "reject", "request_change", "override"] and
          blank?(workflow_form_value(form, "reason")) ->
        {:error, "A reason is required for this workflow action."}

      action == "escalate" and blank?(workflow_form_value(form, "reason")) ->
        {:error, "Escalation requires a reason."}

      action == "reassign" and
        blank?(workflow_form_value(form, "assigned_account_id")) and
          blank?(workflow_form_value(form, "assigned_role")) ->
        {:error, "Reassign requires an account or role target."}

      action == "comment" and blank?(workflow_form_value(form, "note")) ->
        {:error, "Comments need a note."}

      action == "override" and
          workflow_form_value(form, "confirm_text") !=
            workflow_override_confirmation_phrase(selected_workflow_item(snapshot)) ->
        {:error, "Type the exact override confirmation phrase before submitting."}

      true ->
        :ok
    end
  end

  def validate_review_form(form, snapshot) do
    cond do
      not console_can_workflow_assign?(snapshot) ->
        {:error, "The configured console actor cannot start workflow reviews."}

      blank?(review_form_value(form, "reason")) ->
        {:error, "A reason is required to start a trace review."}

      true ->
        :ok
    end
  end

  def selected_workflow_id_result(snapshot) do
    case selected_workflow_id(snapshot) do
      nil -> {:error, "Select a workflow item first."}
      workflow_id -> {:ok, workflow_id}
    end
  end

  def selected_trace_id_result(snapshot) do
    case selected_trace_id(snapshot) do
      nil -> {:error, "Select a trace first."}
      trace_id -> {:ok, trace_id}
    end
  end

  def replay_confirmation_phrase(form) do
    "#{String.upcase(replay_form_value(form, "mode"))} #{String.upcase(replay_form_value(form, "projection"))}"
  end

  def replay_projection_options, do: @replay_projections
  def replay_form_value(form, key), do: Map.get(form, key, "")
  def review_form_value(form, key), do: Map.get(form, key, "")
  def workflow_form_value(form, key), do: Map.get(form, key, "")
  def normalize_replay_mode(mode) when mode in ["catch_up", "rebuild"], do: mode
  def normalize_replay_mode(_mode), do: "catch_up"

  def normalize_replay_projection(projection) when projection in @replay_projections,
    do: projection

  def normalize_replay_projection(_projection), do: "trace_summary"

  def console_alerts(snapshot), do: Map.get(snapshot, :alerts, [])
  def section_ready?(%{status: "ready"}), do: true
  def section_ready?(_section), do: false

  def projection_rows(snapshot),
    do: get_in(snapshot, [:projection_health, :data, "projections"]) || []

  def recent_traces(snapshot), do: get_in(snapshot, [:recent_traces, :items]) || []

  def selected_trace_events(snapshot),
    do: get_in(snapshot, [:selected_trace, :data, "events"]) || []

  def selected_trace_summary(snapshot),
    do: get_in(snapshot, [:selected_trace, :data, "summary"]) || %{}

  def selected_trace_id(snapshot), do: get_in(snapshot, [:selected_trace, :trace_id])

  def trace_handoff(snapshot),
    do: get_in(snapshot, [:selected_trace, :data, "investigator_handoff"])

  def graph_data(snapshot), do: get_in(snapshot, [:context_graph, :data]) || %{}
  def graph_nodes(snapshot), do: get_in(snapshot, [:context_graph, :data, "nodes"]) || []
  def graph_edges(snapshot), do: get_in(snapshot, [:context_graph, :data, "edges"]) || []
  def precedent_focus(snapshot), do: get_in(snapshot, [:precedents, :data, "focus"]) || %{}
  def precedent_items(snapshot), do: get_in(snapshot, [:precedents, :data, "items"]) || []
  def policy_review_data(snapshot), do: get_in(snapshot, [:policy_review, :data]) || %{}
  def policy_timeline(snapshot), do: get_in(snapshot, [:policy_review, :data, "timeline"]) || []
  def replay_runs(snapshot), do: get_in(snapshot, [:replay_console, :data, "runs"]) || []

  def replay_failures(snapshot),
    do: get_in(snapshot, [:replay_console, :data, "latest_failures"]) || []

  def replay_digest_rows(snapshot),
    do: get_in(snapshot, [:replay_console, :data, "projection_digests"]) || []

  def replay_full_digest(snapshot), do: get_in(snapshot, [:replay_console, :data, "full_digest"])
  def event_stream_items(snapshot), do: get_in(snapshot, [:event_stream, :items]) || []
  def tenant_status_data(snapshot), do: get_in(snapshot, [:tenant_status, :data]) || %{}

  def workflow_inbox_items(snapshot),
    do: get_in(snapshot, [:workflow_inbox, :data, "items"]) || []

  def workflow_actions(snapshot),
    do: get_in(snapshot, [:selected_workflow, :data, "actions"]) || []

  def workflow_notifications(snapshot),
    do: get_in(snapshot, [:selected_workflow, :data, "notifications"]) || []

  def workflow_review_context(snapshot),
    do: get_in(snapshot, [:selected_workflow, :data, "review_context"])

  def selected_workflow_item(snapshot),
    do: get_in(snapshot, [:selected_workflow, :data, "workflow"]) || %{}

  def selected_workflow_id(snapshot), do: get_in(snapshot, [:selected_workflow, :workflow_id])

  def review_studio_templates(snapshot),
    do: get_in(snapshot, [:review_studio, :data, "templates"]) || []

  def review_studio_template(snapshot),
    do: get_in(snapshot, [:review_studio, :data, "template"]) || %{}

  def review_studio_simulation(snapshot),
    do: get_in(snapshot, [:review_studio, :data, "simulation"]) || %{}

  def review_studio_existing_workflows(snapshot),
    do: get_in(snapshot, [:review_studio, :data, "existing_workflows"]) || []

  def review_studio_precedents(snapshot),
    do: get_in(snapshot, [:review_studio, :data, "precedent_preview"]) || []

  def review_studio_replay(snapshot),
    do: get_in(snapshot, [:review_studio, :data, "replay_suggestion"]) || %{}

  def review_studio_draft(snapshot),
    do: get_in(snapshot, [:review_studio, :data, "draft"]) || %{}

  def tenant_workflows(snapshot),
    do: get_in(snapshot, [:tenant_status, :data, "workflows"]) || []

  def environment_status_data(snapshot),
    do: get_in(snapshot, [:environment_status, :data]) || %{}

  def tenant_metric(snapshot, key), do: get_in(snapshot, [:tenant_status, :data, key]) || 0
  def trace_selected?(snapshot, trace_id), do: selected_trace_id(snapshot) == trace_id

  def workflow_selected?(snapshot, workflow_id),
    do: selected_workflow_id(snapshot) == workflow_id

  def workflow_summary_metric(snapshot, key),
    do: get_in(snapshot, [:workflow_inbox, :summary, key]) || 0

  def console_actions_enabled?(snapshot) do
    get_in(snapshot, [:console_controls, :data, "actions_enabled"]) in [true, "true"]
  end

  def console_can_rebuild?(snapshot) do
    get_in(snapshot, [:console_controls, :data, "can_rebuild"]) in [true, "true"]
  end

  def console_actor_label(snapshot) do
    get_in(snapshot, [:console_controls, :data, "account_id"]) || "disabled"
  end

  def workflow_actions_enabled?(snapshot) do
    console_can_workflow_review?(snapshot) or console_can_workflow_assign?(snapshot) or
      console_can_workflow_override?(snapshot) or console_can_workflow_escalate?(snapshot)
  end

  def workflow_action_options(snapshot) do
    []
    |> maybe_push(console_can_workflow_review?(snapshot), "approve")
    |> maybe_push(console_can_workflow_review?(snapshot), "reject")
    |> maybe_push(console_can_workflow_review?(snapshot), "request_change")
    |> maybe_push(console_can_workflow_review?(snapshot), "comment")
    |> maybe_push(console_can_workflow_escalate?(snapshot), "escalate")
    |> maybe_push(console_can_workflow_assign?(snapshot), "reassign")
    |> maybe_push(console_can_workflow_override?(snapshot), "override")
  end

  def console_can_workflow_review?(snapshot) do
    get_in(snapshot, [:console_controls, :data, "can_workflow_review"]) in [true, "true"]
  end

  def console_can_workflow_assign?(snapshot) do
    get_in(snapshot, [:console_controls, :data, "can_workflow_assign"]) in [true, "true"]
  end

  def console_can_workflow_escalate?(snapshot) do
    get_in(snapshot, [:console_controls, :data, "can_workflow_escalate"]) in [true, "true"]
  end

  def console_can_workflow_override?(snapshot) do
    get_in(snapshot, [:console_controls, :data, "can_workflow_override"]) in [true, "true"]
  end

  def workflow_override_confirmation_phrase(workflow) do
    "OVERRIDE " <> String.upcase(Map.get(workflow || %{}, "workflow_id", ""))
  end

  def string_value(map, key, default) do
    map
    |> value_from(key, default)
    |> to_string()
    |> String.trim()
  end

  def value_from(map, key, default \\ nil)

  def value_from(map, key, default) when is_map(map) do
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

  def value_from(_map, _key, default), do: default
  def maybe_put(map, _key, nil), do: map
  def maybe_put(map, key, value), do: Map.put(map, key, value)
  def maybe_push(list, true, value), do: list ++ [value]
  def maybe_push(list, false, _value), do: list
  def blank_to_nil(value) when is_binary(value) and value == "", do: nil
  def blank_to_nil(value) when is_binary(value), do: value
  def blank_to_nil(nil), do: nil
  def blank_to_nil(value), do: value
  def blank?(nil), do: true
  def blank?(value) when is_binary(value), do: String.trim(value) == ""
  def blank?(_value), do: false

  def normalize_param(nil, fallback), do: fallback

  def normalize_param(value, _fallback) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> "default"
      normalized -> normalized
    end
  end

  def normalize_optional_param(nil), do: nil

  def normalize_optional_param(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end
end
