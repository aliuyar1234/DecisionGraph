defmodule DecisionGraph.Api.Workflows do
  @moduledoc false

  alias DecisionGraph.Api
  alias DecisionGraph.Api.{Audit, Errors, HttpError, ServiceAccount}
  alias DecisionGraph.Error
  alias DecisionGraph.Projector.SQL

  @default_limit 12
  @default_notification_limit 12
  @max_limit 50
  @open_statuses ["requested", "in_review", "changes_requested", "escalated"]
  @terminal_statuses ["approved", "rejected", "overridden"]
  @managed_event_types ["ApprovalRecorded", "ExceptionRequested", "WorkflowReviewRequested"]
  @workflow_kind "exception_review"
  @trace_review_subject_type "trace_review"

  @spec list_inbox(map(), keyword()) :: {:ok, map()} | {:error, HttpError.t()}
  def list_inbox(params \\ %{}, opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id) |> normalize_tenant_id()
    filters = normalize_filters(params)

    refresh_runtime!(tenant_id)

    {:ok,
     %{
       filters: filters,
       items: tenant_id |> inbox_query(filters) |> Enum.map(&workflow_row/1),
       summary: summary_for(tenant_id)
     }}
  rescue
    error -> {:error, Errors.from_exception(error)}
  end

  @spec get_workflow(String.t(), keyword()) :: {:ok, map()} | {:error, HttpError.t()}
  def get_workflow(workflow_id, opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id) |> normalize_tenant_id()
    workflow_id = normalize_required_string(workflow_id, :workflow_id)

    refresh_runtime!(tenant_id)

    with {:ok, item} <- fetch_workflow(workflow_id, tenant_id) do
      actions =
        SQL.query_all!(
          """
          SELECT action_id, actor_account_id, actor_id, actor_type, action_type, created_at, note,
                 payload_json, resulting_status, source_event_id, tenant_id, trace_id, workflow_id
          FROM dg_workflow_actions
          WHERE tenant_id = $1 AND workflow_id = $2
          ORDER BY created_at ASC, action_id ASC
          """,
          [tenant_id, workflow_id]
        )

      {:ok,
       %{
         actions: Enum.map(actions, &action_row/1),
         notifications: workflow_notifications(tenant_id, workflow_id),
         review_context: review_context_for(tenant_id, item),
         trace_reference: trace_reference(item),
         workflow: workflow_row(item)
       }}
    end
  rescue
    error -> {:error, Errors.from_exception(error)}
  end

  @spec act_on_workflow(String.t(), map(), keyword()) :: {:ok, map()} | {:error, HttpError.t()}
  def act_on_workflow(workflow_id, attrs, opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id) |> normalize_tenant_id()
    actor = Keyword.get(opts, :actor)
    request_id = Keyword.get(opts, :request_id)
    workflow_id = normalize_required_string(workflow_id, :workflow_id)
    action = normalize_action(attrs)

    refresh_runtime!(tenant_id)

    with {:ok, item} <- fetch_workflow(workflow_id, tenant_id),
         :ok <- authorize_action(actor, action),
         :ok <- validate_transition(item, action),
         {:ok, result} <- apply_action(item, action, attrs, tenant_id, actor, request_id),
         {:ok, updated_item} <- fetch_workflow(workflow_id, tenant_id) do
      {:ok,
       %{
         action: result,
         workflow: workflow_row(updated_item)
       }}
    end
  rescue
    error -> {:error, Errors.from_exception(error)}
  end

  @spec export_workflow(String.t(), keyword()) :: {:ok, map()} | {:error, HttpError.t()}
  def export_workflow(workflow_id, opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id) |> normalize_tenant_id()
    actor = Keyword.get(opts, :actor)
    workflow_id = normalize_required_string(workflow_id, :workflow_id)

    with :ok <- authorize_action(actor, "export"),
         {:ok, detail} <- get_workflow(workflow_id, tenant_id: tenant_id) do
      workflow = Map.fetch!(detail, :workflow)
      actions = Map.fetch!(detail, :actions)
      notifications = Map.get(detail, :notifications, [])

      {:ok,
       %{
         audit_summary: %{
           action_count: length(actions),
           closed?: workflow["status"] in @terminal_statuses,
           current_decision: workflow["current_decision"],
           notification_count: length(notifications),
           overdue: workflow["overdue"],
           workflow_kind: workflow["workflow_kind"]
         },
         exported_at: SQL.now_rfc3339(),
         export_version: 1,
         trace_reference: Map.fetch!(detail, :trace_reference),
         workflow: workflow,
         workflow_actions: actions,
         workflow_notifications: notifications
       }}
    end
  rescue
    error -> {:error, Errors.from_exception(error)}
  end

  @spec list_templates(keyword()) :: {:ok, [map()]} | {:error, HttpError.t()}
  def list_templates(_opts \\ []) do
    {:ok, workflow_templates()}
  rescue
    error -> {:error, Errors.from_exception(error)}
  end

  @spec simulate_trace_review(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, HttpError.t()}
  def simulate_trace_review(trace_id, params \\ %{}, opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id) |> normalize_tenant_id()
    trace_id = normalize_required_string(trace_id, :trace_id)
    refresh_runtime!(tenant_id)

    with {:ok, trace} <- Api.service(:traces).get_trace(trace_id, tenant_id: tenant_id) do
      template =
        params
        |> Map.get("template_id", Map.get(params, :template_id))
        |> resolve_template(trace)

      {:ok, build_review_studio(trace_id, trace, tenant_id, template)}
    end
  rescue
    error -> {:error, Errors.from_exception(error)}
  end

  @spec start_trace_review(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, HttpError.t()}
  def start_trace_review(trace_id, attrs, opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id) |> normalize_tenant_id()
    actor = Keyword.get(opts, :actor)
    request_id = Keyword.get(opts, :request_id)
    trace_id = normalize_required_string(trace_id, :trace_id)
    reason = required_reason(attrs, "start_review")

    with :ok <- authorize_trace_review_start(actor),
         {:ok, studio} <- simulate_trace_review(trace_id, attrs, tenant_id: tenant_id),
         draft <- Map.fetch!(studio, "draft"),
         workflow_id <- Map.fetch!(draft, "workflow_id"),
         nil <- raw_workflow(workflow_id, tenant_id),
         {:ok, result} <-
           append_trace_review_request(
             trace_id,
             draft,
             studio,
             reason,
             tenant_id,
             actor,
             request_id
           ),
         :ok <- refresh_runtime!(tenant_id),
         {:ok, detail} <- get_workflow(workflow_id, tenant_id: tenant_id) do
      {:ok,
       %{
         action: %{
           "appended_event_id" => response_event_id(result),
           "outcome" => "start_review"
         },
         created: true,
         review_context: Map.get(detail, :review_context),
         workflow: Map.fetch!(detail, :workflow)
       }}
    else
      %{} = existing ->
        {:ok,
         %{
           action: %{"appended_event_id" => nil, "outcome" => "start_review"},
           created: false,
           review_context: review_context_for(tenant_id, existing),
           workflow: workflow_row(existing)
         }}

      error ->
        error
    end
  rescue
    error -> {:error, Errors.from_exception(error)}
  end

  @spec summary(keyword()) :: {:ok, map()} | {:error, HttpError.t()}
  def summary(opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id) |> normalize_tenant_id()
    refresh_runtime!(tenant_id)
    {:ok, summary_for(tenant_id)}
  rescue
    error -> {:error, Errors.from_exception(error)}
  end

  defp refresh_runtime!(tenant_id) do
    case SQL.transaction(fn -> refresh_runtime_transaction!(tenant_id) end) do
      {:ok, _result} -> :ok
      {:error, error} -> raise error
    end
  end

  defp refresh_runtime_transaction!(tenant_id) do
    now = SQL.now_rfc3339()

    SQL.execute!(
      """
      INSERT INTO dg_workflow_runtime (tenant_id, last_log_seq, updated_at)
      VALUES ($1, 0, $2)
      ON CONFLICT (tenant_id) DO NOTHING
      """,
      [tenant_id, now]
    )

    last_log_seq =
      SQL.query_one!(
        """
        SELECT last_log_seq
        FROM dg_workflow_runtime
        WHERE tenant_id = $1
        FOR UPDATE
        """,
        [tenant_id]
      )
      |> Map.get("last_log_seq", 0)

    rows =
      SQL.query_all!(
        """
        SELECT actor_id, actor_type, event_id, event_type, log_seq, occurred_at, payload_json, trace_id
        FROM dg_event_log
        WHERE tenant_id = $1 AND log_seq > $2 AND event_type = ANY($3)
        ORDER BY log_seq ASC
        """,
        [tenant_id, last_log_seq, @managed_event_types]
      )

    processed_log_seq =
      Enum.reduce(rows, last_log_seq, fn row, _acc ->
        apply_source_event!(tenant_id, row)
        row["log_seq"]
      end)

    SQL.execute!(
      """
      UPDATE dg_workflow_runtime
      SET last_log_seq = $2,
          updated_at = $3
      WHERE tenant_id = $1
      """,
      [tenant_id, processed_log_seq, now]
    )

    run_notification_and_sla_sweep!(tenant_id, now)

    :ok
  end

  defp apply_source_event!(tenant_id, %{"event_type" => "ExceptionRequested"} = row) do
    payload = decode_json(row["payload_json"])
    subject_id = normalize_required_string(payload["exception_id"], :exception_id)
    workflow_id = workflow_id_for(row["trace_id"], "exception", subject_id)
    trace_context = trace_context_for(tenant_id, row["trace_id"], payload)
    existing = raw_workflow(workflow_id, tenant_id)
    updated_at = row["occurred_at"]

    attrs = %{
      approval_event_id: existing_field(existing, "approval_event_id"),
      assigned_account_id:
        existing_field(existing, "assigned_account_id", default_assigned_account_id()),
      assigned_role: existing_field(existing, "assigned_role", default_assigned_role()),
      created_from_event_id: row["event_id"],
      current_decision: existing_field(existing, "current_decision"),
      current_reason: payload["reason"] || existing_field(existing, "current_reason"),
      last_action_at: updated_at,
      last_action_type: "requested",
      last_source_log_seq: row["log_seq"],
      metadata_json:
        encode_json(%{
          "evidence" => List.wrap(payload["evidence"]),
          "exception_reason" => payload["reason"],
          "policy" => %{
            "policy_id" => payload_value(payload, ["policy", "policy_id"]),
            "policy_version" => payload_value(payload, ["policy", "policy_version"])
          },
          "request_event_id" => row["event_id"],
          "workflow" => trace_context.workflow_name
        }),
      policy_id: payload_value(payload, ["policy", "policy_id"]),
      policy_version: payload_value(payload, ["policy", "policy_version"]),
      priority: priority_for(payload, existing),
      requested_at: existing_field(existing, "requested_at", updated_at),
      requested_by_actor_id: row["actor_id"],
      requested_by_actor_type: row["actor_type"],
      resolved_at:
        if terminal_status?(existing_field(existing, "status")) do
          existing_field(existing, "resolved_at")
        else
          nil
        end,
      sla_due_at: existing_field(existing, "sla_due_at", add_sla_hours(updated_at)),
      status:
        if(
          terminal_status?(existing_field(existing, "status")),
          do: existing_field(existing, "status"),
          else: "requested"
        ),
      subject_id: subject_id,
      subject_type: "exception",
      tenant_id: tenant_id,
      title: trace_context.title,
      trace_id: row["trace_id"],
      updated_at: updated_at,
      workflow_id: workflow_id,
      workflow_kind: @workflow_kind,
      workflow_name: trace_context.workflow_name
    }

    upsert_workflow!(attrs)

    insert_source_action!(%{
      action_type: "requested",
      actor_account_id: nil,
      actor_id: row["actor_id"],
      actor_type: row["actor_type"],
      created_at: updated_at,
      note: payload["reason"],
      payload_json:
        encode_json(%{
          "evidence" => List.wrap(payload["evidence"]),
          "exception_id" => subject_id,
          "policy" => payload["policy"]
        }),
      resulting_status: attrs.status,
      source_event_id: row["event_id"],
      tenant_id: tenant_id,
      trace_id: row["trace_id"],
      workflow_id: workflow_id
    })

    insert_notification!(
      notification_attrs(
        attrs,
        "assignment",
        "Workflow #{workflow_id} assigned to #{assignment_target_label(attrs)}",
        %{
          "assigned_account_id" => attrs.assigned_account_id,
          "assigned_role" => attrs.assigned_role,
          "source" => "exception_requested"
        },
        dedupe_key:
          "assignment:#{workflow_id}:#{attrs.assigned_account_id || attrs.assigned_role || "unassigned"}"
      )
    )
  end

  defp apply_source_event!(tenant_id, %{"event_type" => "ApprovalRecorded"} = row) do
    payload = decode_json(row["payload_json"])
    subject_type = payload_value(payload, ["subject", "subject_type"]) || "exception"
    subject_id = payload_value(payload, ["subject", "subject_id"])
    workflow_id = workflow_lookup_id(row["trace_id"], subject_type, subject_id)
    existing = raw_workflow(workflow_id, tenant_id)
    trace_context = trace_context_for(tenant_id, row["trace_id"], %{})
    decision = payload["decision"]
    next_status = approval_status(subject_type, decision)
    reason = payload["reason"] || payload["rationale"]

    attrs = %{
      approval_event_id: row["event_id"],
      assigned_account_id: existing_field(existing, "assigned_account_id"),
      assigned_role: existing_field(existing, "assigned_role"),
      created_from_event_id: existing_field(existing, "created_from_event_id", row["event_id"]),
      current_decision: decision_label(subject_type, decision),
      current_reason: reason,
      last_action_at: row["occurred_at"],
      last_action_type: approval_action_type(subject_type, decision),
      last_source_log_seq: row["log_seq"],
      metadata_json:
        encode_json(
          merge_workflow_metadata(existing_field(existing, "metadata_json"), %{
            "approval_event_id" => row["event_id"],
            "approval_reason" => reason,
            "approver" => payload["approver"],
            "evidence" => List.wrap(payload["evidence"])
          })
        ),
      policy_id: existing_field(existing, "policy_id"),
      policy_version: existing_field(existing, "policy_version"),
      priority: existing_field(existing, "priority", "high"),
      requested_at: existing_field(existing, "requested_at", row["occurred_at"]),
      requested_by_actor_id:
        existing_field(
          existing,
          "requested_by_actor_id",
          payload_value(payload, ["approver", "actor_id"])
        ),
      requested_by_actor_type:
        existing_field(
          existing,
          "requested_by_actor_type",
          payload_value(payload, ["approver", "actor_type"])
        ),
      resolved_at: row["occurred_at"],
      sla_due_at: existing_field(existing, "sla_due_at"),
      status: next_status,
      subject_id: subject_id || existing_field(existing, "subject_id", workflow_id),
      subject_type: subject_type,
      tenant_id: tenant_id,
      title: existing_field(existing, "title", trace_context.title),
      trace_id: row["trace_id"],
      updated_at: row["occurred_at"],
      workflow_id: workflow_id,
      workflow_kind: existing_field(existing, "workflow_kind", workflow_kind_for(subject_type)),
      workflow_name: existing_field(existing, "workflow_name", trace_context.workflow_name)
    }

    upsert_workflow!(attrs)

    insert_source_action!(%{
      action_type: approval_action_type(subject_type, decision),
      actor_account_id: nil,
      actor_id: payload_value(payload, ["approver", "actor_id"]) || row["actor_id"],
      actor_type: payload_value(payload, ["approver", "actor_type"]) || row["actor_type"],
      created_at: row["occurred_at"],
      note: reason,
      payload_json:
        encode_json(%{
          "decision" => decision,
          "evidence" => List.wrap(payload["evidence"]),
          "subject" => payload["subject"]
        }),
      resulting_status: next_status,
      source_event_id: row["event_id"],
      tenant_id: tenant_id,
      trace_id: row["trace_id"],
      workflow_id: workflow_id
    })

    insert_notification!(
      notification_attrs(
        attrs,
        "approval",
        "Workflow #{workflow_id} recorded #{decision_label(subject_type, decision)}",
        %{
          "decision" => decision,
          "source_event_id" => row["event_id"],
          "subject_type" => subject_type
        },
        dedupe_key: "approval:#{workflow_id}:#{row["event_id"]}"
      )
    )
  end

  defp apply_source_event!(tenant_id, %{"event_type" => "WorkflowReviewRequested"} = row) do
    payload = decode_json(row["payload_json"])
    template_id = normalize_required_string(payload["template_id"], :template_id)
    subject = payload["subject"] || %{}
    subject_type = payload_value(subject, ["subject_type"]) || @trace_review_subject_type
    subject_id = payload_value(subject, ["subject_id"]) || template_id
    workflow_id = workflow_id_for(row["trace_id"], subject_type, subject_id)
    trace_context = trace_context_for(tenant_id, row["trace_id"], payload)
    existing = raw_workflow(workflow_id, tenant_id)
    updated_at = row["occurred_at"]
    assignee = payload["assignee"] || %{}

    attrs = %{
      approval_event_id: existing_field(existing, "approval_event_id"),
      assigned_account_id:
        payload_value(assignee, ["account_id"]) ||
          existing_field(existing, "assigned_account_id"),
      assigned_role:
        payload_value(assignee, ["role"]) ||
          existing_field(existing, "assigned_role", default_assigned_role()),
      created_from_event_id: row["event_id"],
      current_decision: existing_field(existing, "current_decision"),
      current_reason: payload["reason"] || existing_field(existing, "current_reason"),
      last_action_at: updated_at,
      last_action_type: "incident_review_requested",
      last_source_log_seq: row["log_seq"],
      metadata_json:
        encode_json(
          merge_workflow_metadata(existing_field(existing, "metadata_json"), %{
            "entrypoint" => "workflow_studio",
            "review_template" => %{
              "default_priority" => payload["priority"],
              "default_sla_hours" => payload["sla_hours"],
              "description" => payload["template_description"],
              "reviewer_role" => payload_value(assignee, ["role"]),
              "template_id" => template_id
            },
            "simulation" => payload["simulation"],
            "source_event_id" => row["event_id"]
          })
        ),
      policy_id: payload["policy_id"],
      policy_version: payload["policy_version"],
      priority:
        priority_for(
          %{"priority" => payload["priority"], "reason" => payload["reason"]},
          existing
        ),
      requested_at: existing_field(existing, "requested_at", updated_at),
      requested_by_actor_id: row["actor_id"],
      requested_by_actor_type: row["actor_type"],
      resolved_at:
        if terminal_status?(existing_field(existing, "status")) do
          existing_field(existing, "resolved_at")
        else
          nil
        end,
      sla_due_at:
        existing_field(
          existing,
          "sla_due_at",
          add_hours(
            updated_at,
            payload["sla_hours"] || workflow_default(:incident_review_sla_hours, 2)
          )
        ),
      status:
        if(
          terminal_status?(existing_field(existing, "status")),
          do: existing_field(existing, "status"),
          else: "requested"
        ),
      subject_id: subject_id,
      subject_type: subject_type,
      tenant_id: tenant_id,
      title: payload["title"] || "Incident review for #{trace_context.title}",
      trace_id: row["trace_id"],
      updated_at: updated_at,
      workflow_id: workflow_id,
      workflow_kind: payload["workflow_kind"] || "incident_review",
      workflow_name: template_id
    }

    upsert_workflow!(attrs)

    insert_source_action!(%{
      action_type: "incident_review_requested",
      actor_account_id: nil,
      actor_id: row["actor_id"],
      actor_type: row["actor_type"],
      created_at: updated_at,
      note: payload["reason"],
      payload_json:
        encode_json(%{
          "assignee" => assignee,
          "simulation" => payload["simulation"],
          "template_id" => template_id
        }),
      resulting_status: attrs.status,
      source_event_id: row["event_id"],
      tenant_id: tenant_id,
      trace_id: row["trace_id"],
      workflow_id: workflow_id
    })

    insert_notification!(
      notification_attrs(
        attrs,
        "assignment",
        "Workflow #{workflow_id} assigned to #{assignment_target_label(attrs)}",
        %{
          "assigned_account_id" => attrs.assigned_account_id,
          "assigned_role" => attrs.assigned_role,
          "source" => "workflow_review_requested",
          "template_id" => template_id
        },
        dedupe_key:
          "assignment:#{workflow_id}:#{attrs.assigned_account_id || attrs.assigned_role || "unassigned"}"
      )
    )
  end

  defp inbox_query(tenant_id, filters) do
    clauses = ["tenant_id = $1"]
    params = [tenant_id]
    {clauses, params} = maybe_add_clause(clauses, params, filters["status"], "status = ?")

    {clauses, params} =
      maybe_add_clause(clauses, params, filters["assigned_account_id"], "assigned_account_id = ?")

    {clauses, params} =
      maybe_add_clause(clauses, params, filters["assigned_role"], "assigned_role = ?")

    {clauses, params} = maybe_add_clause(clauses, params, filters["priority"], "priority = ?")
    {clauses, params} = maybe_add_clause(clauses, params, filters["trace_id"], "trace_id = ?")

    {clauses, params} =
      if filters["only_open"] do
        add_clause(clauses, params, "status = ANY(?)", @open_statuses)
      else
        {clauses, params}
      end

    {clauses, params} =
      if filters["only_overdue"] do
        overdue_sql =
          "status = ANY(?) AND sla_due_at IS NOT NULL AND sla_due_at < ?"

        clauses = clauses ++ [replace_placeholders(overdue_sql, length(params) + 1, 2)]
        {clauses, params ++ [@open_statuses, SQL.now_rfc3339()]}
      else
        {clauses, params}
      end

    SQL.query_all!(
      """
      SELECT approval_event_id, assigned_account_id, assigned_role, created_from_event_id,
             current_decision, current_reason, last_action_at, last_action_type, last_source_log_seq,
             metadata_json, policy_id, policy_version, priority, requested_at, requested_by_actor_id,
             requested_by_actor_type, resolved_at, sla_due_at, status, subject_id, subject_type,
             tenant_id, title, trace_id, updated_at, workflow_id, workflow_kind, workflow_name
      FROM dg_workflow_items
      WHERE #{Enum.join(clauses, " AND ")}
      ORDER BY
        CASE
          WHEN status = ANY($#{length(params) + 1}) AND sla_due_at IS NOT NULL AND sla_due_at < $#{length(params) + 2} THEN 0
          ELSE 1
        END ASC,
        CASE priority
          WHEN 'urgent' THEN 0
          WHEN 'high' THEN 1
          WHEN 'normal' THEN 2
          ELSE 3
        END ASC,
        requested_at ASC,
        workflow_id ASC
      LIMIT $#{length(params) + 3}
      """,
      params ++ [@open_statuses, SQL.now_rfc3339(), filters["limit"]]
    )
  end

  defp summary_for(tenant_id) do
    SQL.query_one!(
      """
      SELECT
        COUNT(*)::int AS total_count,
        COUNT(*) FILTER (WHERE status = ANY($2))::int AS open_count,
        COUNT(*) FILTER (
          WHERE status = ANY($2) AND sla_due_at IS NOT NULL AND sla_due_at < $3
        )::int AS overdue_count,
        COUNT(*) FILTER (WHERE status = 'requested')::int AS requested_count,
        COUNT(*) FILTER (WHERE status = 'changes_requested')::int AS changes_requested_count,
        COUNT(*) FILTER (WHERE status = 'approved')::int AS approved_count,
        COUNT(*) FILTER (WHERE status = 'rejected')::int AS rejected_count,
        COUNT(*) FILTER (WHERE status = 'overridden')::int AS overridden_count,
        COUNT(*) FILTER (WHERE status = 'escalated')::int AS escalated_count
      FROM dg_workflow_items
      WHERE tenant_id = $1
      """,
      [tenant_id, @open_statuses, SQL.now_rfc3339()]
    )
    |> Map.put("tenant_id", tenant_id)
    |> Map.put(
      "notification_count",
      SQL.query_one!(
        """
        SELECT COUNT(*)::int AS notification_count
        FROM dg_workflow_notifications
        WHERE tenant_id = $1
        """,
        [tenant_id]
      )["notification_count"] || 0
    )
  end

  defp fetch_workflow(workflow_id, tenant_id) do
    case raw_workflow(workflow_id, tenant_id) do
      %{} = item -> {:ok, item}
      nil -> {:error, not_found_workflow(workflow_id)}
    end
  end

  defp raw_workflow(workflow_id, tenant_id) do
    SQL.query_all!(
      """
      SELECT approval_event_id, assigned_account_id, assigned_role, created_from_event_id,
             current_decision, current_reason, last_action_at, last_action_type, last_source_log_seq,
             metadata_json, policy_id, policy_version, priority, requested_at, requested_by_actor_id,
             requested_by_actor_type, resolved_at, sla_due_at, status, subject_id, subject_type,
             tenant_id, title, trace_id, updated_at, workflow_id, workflow_kind, workflow_name
      FROM dg_workflow_items
      WHERE tenant_id = $1 AND workflow_id = $2
      LIMIT 1
      """,
      [tenant_id, workflow_id]
    )
    |> List.first()
  end

  defp apply_action(item, action, attrs, tenant_id, actor, request_id)
       when action in ["approve", "reject"] do
    reason = required_reason(attrs, action)
    evidence = normalize_evidence(Map.get(attrs, "evidence", Map.get(attrs, :evidence)))

    with {:ok, result} <-
           append_approval_event(item, action, reason, evidence, tenant_id, actor, request_id) do
      refresh_runtime!(tenant_id)

      {:ok,
       %{
         appended_event_id: response_event_id(result),
         outcome: action
       }}
    end
  end

  defp apply_action(item, "override", attrs, tenant_id, actor, request_id) do
    reason = required_reason(attrs, "override")

    confirm_text =
      normalize_optional_string(Map.get(attrs, "confirm_text", Map.get(attrs, :confirm_text)))

    expected_confirmation = "OVERRIDE " <> String.upcase(item["workflow_id"])

    if confirm_text != expected_confirmation do
      {:error,
       Errors.invalid_argument("Override confirmation phrase must match #{expected_confirmation}")}
    else
      evidence = normalize_evidence(Map.get(attrs, "evidence", Map.get(attrs, :evidence)))

      with {:ok, result} <-
             append_approval_event(
               item,
               "override",
               reason,
               evidence,
               tenant_id,
               actor,
               request_id
             ) do
        refresh_runtime!(tenant_id)

        {:ok,
         %{
           appended_event_id: response_event_id(result),
           outcome: "override"
         }}
      end
    end
  end

  defp apply_action(item, "request_change", attrs, tenant_id, actor, request_id) do
    note = required_reason(attrs, "request_change")

    payload = %{
      "evidence" => normalize_evidence(Map.get(attrs, "evidence", Map.get(attrs, :evidence)))
    }

    now = SQL.now_rfc3339()

    update_workflow_item!(
      item["workflow_id"],
      tenant_id,
      %{
        current_reason: note,
        last_action_at: now,
        last_action_type: "request_change",
        resolved_at: nil,
        status: "changes_requested",
        updated_at: now
      }
    )

    insert_manual_action!(
      "request_change",
      item,
      tenant_id,
      actor,
      note,
      payload,
      "changes_requested"
    )

    audit_workflow_action("request_change", :accepted,
      account_id: actor && actor.account_id,
      request_id: request_id,
      tenant_id: tenant_id,
      workflow_id: item["workflow_id"]
    )

    {:ok, %{outcome: "request_change"}}
  end

  defp apply_action(item, "escalate", attrs, tenant_id, actor, request_id) do
    reason = required_reason(attrs, "escalate")
    now = SQL.now_rfc3339()

    updated_item =
      escalate_workflow!(
        item,
        tenant_id,
        now,
        actor && actor.account_id,
        reason,
        "manual_escalation"
      )

    audit_workflow_action("escalate", :accepted,
      account_id: actor && actor.account_id,
      request_id: request_id,
      tenant_id: tenant_id,
      workflow_id: item["workflow_id"]
    )

    {:ok, %{escalated_to: assignment_target_label(updated_item), outcome: "escalate"}}
  end

  defp apply_action(item, "reassign", attrs, tenant_id, actor, request_id) do
    assigned_account_id =
      normalize_optional_string(
        Map.get(attrs, "assigned_account_id", Map.get(attrs, :assigned_account_id))
      )

    assigned_role =
      normalize_optional_string(Map.get(attrs, "assigned_role", Map.get(attrs, :assigned_role)))

    if assigned_account_id in [nil, ""] and assigned_role in [nil, ""] do
      {:error, Errors.invalid_argument("Reassign requires assigned_account_id or assigned_role")}
    else
      note = normalize_optional_string(Map.get(attrs, "note", Map.get(attrs, :note)))
      now = SQL.now_rfc3339()

      update_workflow_item!(
        item["workflow_id"],
        tenant_id,
        %{
          assigned_account_id: assigned_account_id,
          assigned_role: assigned_role,
          last_action_at: now,
          last_action_type: "reassign",
          updated_at: now
        }
      )

      insert_manual_action!(
        "reassign",
        item,
        tenant_id,
        actor,
        note,
        %{
          "assigned_account_id" => assigned_account_id,
          "assigned_role" => assigned_role
        },
        item["status"]
      )

      notification_item =
        Map.merge(item, %{
          "assigned_account_id" => assigned_account_id,
          "assigned_role" => assigned_role,
          "trace_id" => item["trace_id"],
          "workflow_id" => item["workflow_id"]
        })

      insert_notification!(
        notification_attrs(
          notification_item,
          "assignment",
          "Workflow #{item["workflow_id"]} reassigned to #{assignment_target_label(notification_item)}",
          %{
            "assigned_account_id" => assigned_account_id,
            "assigned_role" => assigned_role,
            "source" => "manual_reassign"
          },
          dedupe_key:
            "assignment:#{item["workflow_id"]}:#{assigned_account_id || assigned_role || "unassigned"}"
        )
      )

      audit_workflow_action("reassign", :accepted,
        account_id: actor && actor.account_id,
        request_id: request_id,
        tenant_id: tenant_id,
        workflow_id: item["workflow_id"]
      )

      {:ok, %{outcome: "reassign"}}
    end
  end

  defp apply_action(item, "comment", attrs, tenant_id, actor, request_id) do
    note =
      normalize_optional_string(
        Map.get(attrs, "note", Map.get(attrs, :note)) ||
          Map.get(attrs, "reason", Map.get(attrs, :reason))
      )

    if note in [nil, ""] do
      {:error, Errors.invalid_argument("Comment note is required")}
    else
      now = SQL.now_rfc3339()

      update_workflow_item!(
        item["workflow_id"],
        tenant_id,
        %{
          last_action_at: now,
          last_action_type: "comment",
          updated_at: now
        }
      )

      insert_manual_action!(
        "comment",
        item,
        tenant_id,
        actor,
        note,
        %{
          "evidence" => normalize_evidence(Map.get(attrs, "evidence", Map.get(attrs, :evidence)))
        },
        item["status"]
      )

      audit_workflow_action("comment", :accepted,
        account_id: actor && actor.account_id,
        request_id: request_id,
        tenant_id: tenant_id,
        workflow_id: item["workflow_id"]
      )

      {:ok, %{outcome: "comment"}}
    end
  end

  defp append_approval_event(item, action, reason, evidence, tenant_id, actor, request_id) do
    trace_id = item["trace_id"]
    trace_seq = DecisionGraph.Store.get_next_trace_seq(trace_id, tenant_id: tenant_id)
    now = SQL.now_rfc3339()
    unique_id = Integer.to_string(System.unique_integer([:positive]))

    subject =
      case action do
        "override" -> %{"subject_id" => item["workflow_id"], "subject_type" => "override"}
        _other -> %{"subject_id" => item["subject_id"], "subject_type" => item["subject_type"]}
      end

    attrs = %{
      "actor" => %{"actor_id" => actor.account_id, "actor_type" => "role"},
      "event_id" => "#{trace_id}-approval-recorded-#{trace_seq}-#{unique_id}",
      "event_type" => "ApprovalRecorded",
      "idempotency_key" =>
        approval_idempotency_key(item["workflow_id"], action, request_id, unique_id),
      "occurred_at" => now,
      "payload" => %{
        "approval_id" => "approval:#{item["workflow_id"]}:#{unique_id}",
        "approver" => %{"actor_id" => actor.account_id, "actor_type" => "role"},
        "decision" => approval_decision(action),
        "evidence" => evidence,
        "reason" => reason,
        "subject" => subject
      },
      "source" => %{
        "producer_id" => "workflow-service",
        "subsystem" => "workflow",
        "system" => "decisiongraph-api"
      },
      "trace_id" => trace_id,
      "trace_seq" => trace_seq
    }

    case Api.service(:events).append_event(attrs, tenant_id: tenant_id, request_id: request_id) do
      {:ok, result} ->
        audit_workflow_action(action, :accepted,
          account_id: actor.account_id,
          request_id: request_id,
          tenant_id: tenant_id,
          workflow_id: item["workflow_id"]
        )

        {:ok, result}

      {:error, error} ->
        audit_workflow_action(action, :rejected,
          account_id: actor.account_id,
          reason: error.message,
          request_id: request_id,
          tenant_id: tenant_id,
          workflow_id: item["workflow_id"]
        )

        insert_notification!(
          notification_attrs(
            item,
            "failure",
            "Workflow #{item["workflow_id"]} failed to record #{action}",
            %{"action" => action, "error" => error.message},
            dedupe_key:
              "failure:#{item["workflow_id"]}:#{action}:#{request_id || System.unique_integer([:positive])}"
          )
        )

        {:error, error}
    end
  end

  defp insert_manual_action!(action_type, item, tenant_id, actor, note, payload, resulting_status) do
    insert_action!(
      %{
        action_type: action_type,
        actor_account_id: actor.account_id,
        actor_id: actor.account_id,
        actor_type: "role",
        created_at: SQL.now_rfc3339(),
        note: note,
        payload_json: encode_json(payload),
        resulting_status: resulting_status,
        source_event_id: nil,
        tenant_id: tenant_id,
        trace_id: item["trace_id"],
        workflow_id: item["workflow_id"]
      },
      allow_duplicates?: true
    )
  end

  defp insert_source_action!(attrs), do: insert_action!(attrs, allow_duplicates?: false)

  defp insert_action!(attrs, opts) do
    action_id =
      case attrs[:source_event_id] do
        nil -> "wfa:" <> Integer.to_string(System.unique_integer([:positive]))
        source_event_id -> "wfa:event:" <> source_event_id
      end

    sql =
      """
      INSERT INTO dg_workflow_actions (
        action_id, tenant_id, workflow_id, trace_id, action_type, actor_id, actor_type,
        actor_account_id, note, payload_json, source_event_id, resulting_status, created_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
      """

    params = [
      action_id,
      attrs[:tenant_id],
      attrs[:workflow_id],
      attrs[:trace_id],
      attrs[:action_type],
      attrs[:actor_id],
      attrs[:actor_type],
      attrs[:actor_account_id],
      attrs[:note],
      attrs[:payload_json],
      attrs[:source_event_id],
      attrs[:resulting_status],
      attrs[:created_at]
    ]

    case Keyword.get(opts, :allow_duplicates?, false) do
      true -> SQL.execute!(sql, params)
      false -> SQL.execute!(sql <> " ON CONFLICT (tenant_id, source_event_id) DO NOTHING", params)
    end

    :ok
  end

  defp upsert_workflow!(attrs) do
    SQL.execute!(
      """
      INSERT INTO dg_workflow_items (
        workflow_id, tenant_id, trace_id, workflow_kind, workflow_name, subject_type, subject_id,
        status, priority, title, policy_id, policy_version, requested_by_actor_id,
        requested_by_actor_type, assigned_account_id, assigned_role, requested_at, sla_due_at,
        updated_at, resolved_at, last_action_type, last_action_at, current_decision, current_reason,
        approval_event_id, created_from_event_id, last_source_log_seq, metadata_json
      )
      VALUES (
        $1, $2, $3, $4, $5, $6, $7,
        $8, $9, $10, $11, $12, $13,
        $14, $15, $16, $17, $18,
        $19, $20, $21, $22, $23, $24,
        $25, $26, $27, $28
      )
      ON CONFLICT (workflow_id)
      DO UPDATE SET
        tenant_id = EXCLUDED.tenant_id,
        trace_id = EXCLUDED.trace_id,
        workflow_kind = EXCLUDED.workflow_kind,
        workflow_name = EXCLUDED.workflow_name,
        subject_type = EXCLUDED.subject_type,
        subject_id = EXCLUDED.subject_id,
        status = EXCLUDED.status,
        priority = EXCLUDED.priority,
        title = EXCLUDED.title,
        policy_id = EXCLUDED.policy_id,
        policy_version = EXCLUDED.policy_version,
        requested_by_actor_id = EXCLUDED.requested_by_actor_id,
        requested_by_actor_type = EXCLUDED.requested_by_actor_type,
        assigned_account_id = EXCLUDED.assigned_account_id,
        assigned_role = EXCLUDED.assigned_role,
        requested_at = EXCLUDED.requested_at,
        sla_due_at = EXCLUDED.sla_due_at,
        updated_at = EXCLUDED.updated_at,
        resolved_at = EXCLUDED.resolved_at,
        last_action_type = EXCLUDED.last_action_type,
        last_action_at = EXCLUDED.last_action_at,
        current_decision = EXCLUDED.current_decision,
        current_reason = EXCLUDED.current_reason,
        approval_event_id = EXCLUDED.approval_event_id,
        created_from_event_id = EXCLUDED.created_from_event_id,
        last_source_log_seq = EXCLUDED.last_source_log_seq,
        metadata_json = EXCLUDED.metadata_json
      """,
      [
        attrs.workflow_id,
        attrs.tenant_id,
        attrs.trace_id,
        attrs.workflow_kind,
        attrs.workflow_name,
        attrs.subject_type,
        attrs.subject_id,
        attrs.status,
        attrs.priority,
        attrs.title,
        attrs.policy_id,
        attrs.policy_version,
        attrs.requested_by_actor_id,
        attrs.requested_by_actor_type,
        attrs.assigned_account_id,
        attrs.assigned_role,
        attrs.requested_at,
        attrs.sla_due_at,
        attrs.updated_at,
        attrs.resolved_at,
        attrs.last_action_type,
        attrs.last_action_at,
        attrs.current_decision,
        attrs.current_reason,
        attrs.approval_event_id,
        attrs.created_from_event_id,
        attrs.last_source_log_seq,
        attrs.metadata_json
      ]
    )
  end

  defp update_workflow_item!(workflow_id, tenant_id, attrs) do
    current =
      raw_workflow(workflow_id, tenant_id) ||
        raise(Error, code: :not_found, message: "Workflow not found: #{workflow_id}")

    merged =
      current
      |> Map.merge(Map.new(attrs, fn {key, value} -> {Atom.to_string(key), value} end))
      |> Map.put("workflow_id", workflow_id)
      |> Map.put("tenant_id", tenant_id)
      |> Map.put(
        "metadata_json",
        normalize_metadata_json(Map.get(attrs, :metadata_json), current["metadata_json"])
      )

    upsert_workflow!(%{
      approval_event_id: merged["approval_event_id"],
      assigned_account_id: merged["assigned_account_id"],
      assigned_role: merged["assigned_role"],
      created_from_event_id: merged["created_from_event_id"],
      current_decision: merged["current_decision"],
      current_reason: merged["current_reason"],
      last_action_at: merged["last_action_at"],
      last_action_type: merged["last_action_type"],
      last_source_log_seq: merged["last_source_log_seq"],
      metadata_json: merged["metadata_json"],
      policy_id: merged["policy_id"],
      policy_version: merged["policy_version"],
      priority: merged["priority"],
      requested_at: merged["requested_at"],
      requested_by_actor_id: merged["requested_by_actor_id"],
      requested_by_actor_type: merged["requested_by_actor_type"],
      resolved_at: merged["resolved_at"],
      sla_due_at: merged["sla_due_at"],
      status: merged["status"],
      subject_id: merged["subject_id"],
      subject_type: merged["subject_type"],
      tenant_id: tenant_id,
      title: merged["title"],
      trace_id: merged["trace_id"],
      updated_at: merged["updated_at"],
      workflow_id: workflow_id,
      workflow_kind: merged["workflow_kind"],
      workflow_name: merged["workflow_name"]
    })

    raw_workflow(workflow_id, tenant_id)
  end

  defp workflow_row(row) do
    overdue? =
      row["status"] in @open_statuses and present?(row["sla_due_at"]) and
        row["sla_due_at"] < SQL.now_rfc3339()

    %{
      "approval_event_id" => row["approval_event_id"],
      "assigned_account_id" => row["assigned_account_id"],
      "assigned_role" => row["assigned_role"],
      "created_from_event_id" => row["created_from_event_id"],
      "current_decision" => row["current_decision"],
      "current_reason" => row["current_reason"],
      "last_action_at" => row["last_action_at"],
      "last_action_type" => row["last_action_type"],
      "last_source_log_seq" => row["last_source_log_seq"],
      "metadata" => decode_json(row["metadata_json"]),
      "overdue" => overdue?,
      "policy_id" => row["policy_id"],
      "policy_version" => row["policy_version"],
      "priority" => row["priority"],
      "requested_at" => row["requested_at"],
      "requested_by_actor" => %{
        "actor_id" => row["requested_by_actor_id"],
        "actor_type" => row["requested_by_actor_type"]
      },
      "resolved_at" => row["resolved_at"],
      "sla_due_at" => row["sla_due_at"],
      "status" => row["status"],
      "subject" => %{
        "subject_id" => row["subject_id"],
        "subject_type" => row["subject_type"]
      },
      "tenant_id" => row["tenant_id"],
      "title" => row["title"],
      "trace_id" => row["trace_id"],
      "updated_at" => row["updated_at"],
      "workflow_id" => row["workflow_id"],
      "workflow_kind" => row["workflow_kind"],
      "workflow_name" => row["workflow_name"]
    }
  end

  defp action_row(row) do
    %{
      "action_id" => row["action_id"],
      "action_type" => row["action_type"],
      "actor" => %{
        "account_id" => row["actor_account_id"],
        "actor_id" => row["actor_id"],
        "actor_type" => row["actor_type"]
      },
      "created_at" => row["created_at"],
      "note" => row["note"],
      "payload" => decode_json(row["payload_json"]),
      "resulting_status" => row["resulting_status"],
      "source_event_id" => row["source_event_id"],
      "trace_id" => row["trace_id"],
      "workflow_id" => row["workflow_id"]
    }
  end

  defp workflow_notifications(tenant_id, workflow_id, limit \\ @default_notification_limit) do
    SQL.query_all!(
      """
      SELECT notification_id, tenant_id, workflow_id, trace_id, category, channel, status, message,
             recipient_account_id, recipient_role, payload_json, created_at, delivered_at
      FROM dg_workflow_notifications
      WHERE tenant_id = $1 AND workflow_id = $2
      ORDER BY created_at DESC, notification_id DESC
      LIMIT $3
      """,
      [tenant_id, workflow_id, limit]
    )
    |> Enum.map(&notification_row/1)
  end

  defp notification_row(row) do
    %{
      "category" => row["category"],
      "channel" => row["channel"],
      "created_at" => row["created_at"],
      "delivered_at" => row["delivered_at"],
      "message" => row["message"],
      "notification_id" => row["notification_id"],
      "payload" => decode_json(row["payload_json"]),
      "recipient_account_id" => row["recipient_account_id"],
      "recipient_role" => row["recipient_role"],
      "status" => row["status"],
      "trace_id" => row["trace_id"],
      "workflow_id" => row["workflow_id"]
    }
  end

  defp review_context_for(tenant_id, item) do
    with {:ok, trace} <- Api.service(:traces).get_trace(item["trace_id"], tenant_id: tenant_id) do
      template_id =
        decode_json(item["metadata_json"])
        |> payload_value(["review_template", "template_id"])
        |> normalize_optional_string()

      studio =
        build_review_studio(
          item["trace_id"],
          trace,
          tenant_id,
          resolve_template(template_id, trace)
        )

      %{
        "existing_workflows" => Map.get(studio, "existing_workflows", []),
        "precedent_preview" => Map.get(studio, "precedent_preview", []),
        "recommended_replay" => Map.get(studio, "replay_suggestion"),
        "simulation" => Map.get(studio, "simulation"),
        "trace_summary" => get_in(trace, [:summary]),
        "templates" => Map.get(studio, "templates", [])
      }
    else
      _error -> nil
    end
  rescue
    _error -> nil
  end

  defp build_review_studio(trace_id, trace, tenant_id, template) do
    precedents =
      case Api.service(:precedents).find_precedents(precedent_query_for_trace(trace),
             tenant_id: tenant_id
           ) do
        {:ok, items} -> Enum.take(items, 4)
        _error -> []
      end

    summary = get_in(trace, [:summary]) || %{}
    events = Map.get(trace, :events, [])
    current_workflows = trace_workflows(tenant_id, trace_id)
    recommended_template = template || resolve_template(nil, trace)
    risk_signals = risk_signals(trace, precedents)
    priority = studio_priority(trace, precedents)
    replay_suggestion = replay_suggestion_for_trace(summary, risk_signals)
    reason = recommended_reason(summary, recommended_template, risk_signals)

    %{
      "draft" => %{
        "assigned_role" => recommended_template["reviewer_role"],
        "policy_id" => template_policy_id(events),
        "policy_version" => template_policy_version(events),
        "priority" => priority,
        "reason" => reason,
        "sla_hours" => recommended_template["default_sla_hours"],
        "subject_id" => recommended_template["template_id"],
        "subject_type" => @trace_review_subject_type,
        "title" =>
          "Incident review for #{Map.get(summary, :title) || Map.get(summary, "title") || trace_id}",
        "workflow_id" =>
          workflow_id_for(
            trace_id,
            @trace_review_subject_type,
            recommended_template["template_id"]
          ),
        "workflow_kind" => recommended_template["workflow_kind"],
        "workflow_name" => recommended_template["template_id"]
      },
      "existing_workflows" => Enum.map(current_workflows, &workflow_row/1),
      "precedent_preview" => precedents,
      "replay_suggestion" => replay_suggestion,
      "simulation" => %{
        "policy_id" => template_policy_id(events),
        "policy_version" => template_policy_version(events),
        "priority" => priority,
        "recommended_reason" => reason,
        "risk_signals" => risk_signals,
        "trace_outcome" => Map.get(summary, :outcome) || Map.get(summary, "outcome")
      },
      "template" => recommended_template,
      "templates" => workflow_templates(),
      "trace_id" => trace_id
    }
  end

  defp trace_reference(item) do
    %{
      "subject_id" => item["subject_id"],
      "subject_type" => item["subject_type"],
      "tenant_id" => item["tenant_id"],
      "trace_id" => item["trace_id"],
      "workflow_name" => item["workflow_name"]
    }
  end

  defp authorize_action(%ServiceAccount{} = actor, action) do
    permission =
      case action do
        action when action in ["approve", "reject", "comment", "request_change"] ->
          "workflow_review"

        "escalate" ->
          "workflow_escalate"

        "reassign" ->
          "workflow_assign"

        "override" ->
          "workflow_override"

        "export" ->
          "workflow_export"
      end

    if ServiceAccount.allows?(actor, permission) do
      :ok
    else
      {:error, Errors.forbidden("Service account lacks #{permission} permission")}
    end
  end

  defp authorize_action(nil, _action) do
    {:error, Errors.forbidden("Service account context is required for workflow actions")}
  end

  defp authorize_trace_review_start(%ServiceAccount{} = actor) do
    if ServiceAccount.allows?(actor, "workflow_assign") do
      :ok
    else
      {:error, Errors.forbidden("Service account lacks workflow_assign permission")}
    end
  end

  defp authorize_trace_review_start(nil) do
    {:error, Errors.forbidden("Service account context is required to start workflow reviews")}
  end

  defp validate_transition(item, action) do
    status = item["status"]

    cond do
      action == "comment" ->
        :ok

      action == "escalate" and status == "escalated" ->
        {:error, Errors.invalid_argument("Workflow #{item["workflow_id"]} is already escalated")}

      status in @terminal_statuses ->
        {:error, Errors.invalid_argument("Workflow #{item["workflow_id"]} is already #{status}")}

      action == "override" and item["workflow_kind"] != @workflow_kind ->
        {:error,
         Errors.invalid_argument("Override is only supported for exception review workflows")}

      true ->
        :ok
    end
  end

  defp trace_context_for(tenant_id, trace_id, payload) do
    case SQL.query_all!(
           """
           SELECT title, workflow
           FROM dg_trace_summary
           WHERE tenant_id = $1 AND trace_id = $2
           LIMIT 1
           """,
           [tenant_id, trace_id]
         ) do
      [row | _rest] ->
        %{title: row["title"], workflow_name: row["workflow"] || payload["workflow"] || "unknown"}

      [] ->
        fallback_trace_context(tenant_id, trace_id, payload)
    end
  end

  defp fallback_trace_context(tenant_id, trace_id, payload) do
    started =
      SQL.query_all!(
        """
        SELECT payload_json
        FROM dg_event_log
        WHERE tenant_id = $1 AND trace_id = $2 AND event_type = 'TraceStarted'
        ORDER BY log_seq ASC
        LIMIT 1
        """,
        [tenant_id, trace_id]
      )
      |> List.first()

    started_payload = if started, do: decode_json(started["payload_json"]), else: %{}

    %{
      title:
        payload_value(started_payload, ["title"]) || payload_value(payload, ["title"]) ||
          "Workflow review for #{trace_id}",
      workflow_name:
        payload_value(started_payload, ["workflow"]) || payload_value(payload, ["workflow"]) ||
          "unknown"
    }
  end

  defp workflow_lookup_id(_trace_id, "override", subject_id) when is_binary(subject_id),
    do: subject_id

  defp workflow_lookup_id(trace_id, subject_type, subject_id),
    do: workflow_id_for(trace_id, subject_type, subject_id)

  defp workflow_id_for(trace_id, subject_type, subject_id) do
    "#{normalize_required_string(trace_id, :trace_id)}:#{normalize_required_string(subject_type, :subject_type)}:#{normalize_required_string(subject_id, :subject_id)}"
  end

  defp workflow_kind_for("override"), do: "override_review"
  defp workflow_kind_for(_subject_type), do: @workflow_kind

  defp workflow_templates do
    [
      %{
        "default_priority" => "high",
        "default_sla_hours" => 2,
        "description" =>
          "Operator-led triage for a trace that needs replay, precedent review, and explicit follow-up.",
        "reviewer_role" => "admin",
        "tags" => ["incident", "replay", "human_review"],
        "template_id" => "incident_triage",
        "title" => "Incident Triage Review",
        "workflow_kind" => "incident_review"
      },
      %{
        "default_priority" => "urgent",
        "default_sla_hours" => 1,
        "description" =>
          "Escalated follow-up for traces that already produced exception requests or unresolved manual approvals.",
        "reviewer_role" => "admin",
        "tags" => ["exception", "approval", "sla"],
        "template_id" => "exception_follow_up",
        "title" => "Exception Follow-Up",
        "workflow_kind" => "incident_review"
      },
      %{
        "default_priority" => "normal",
        "default_sla_hours" => 6,
        "description" =>
          "Review path for traces whose closest precedents disagree or provide weak operator confidence.",
        "reviewer_role" => "writer",
        "tags" => ["precedent", "analysis", "dry_run"],
        "template_id" => "precedent_gap_review",
        "title" => "Precedent Gap Review",
        "workflow_kind" => "incident_review"
      }
    ]
  end

  defp resolve_template(nil, trace) do
    default_template_id =
      trace
      |> default_template_id()

    Enum.find(workflow_templates(), &(Map.get(&1, "template_id") == default_template_id)) ||
      List.first(workflow_templates())
  end

  defp resolve_template(template_id, trace) do
    normalized = normalize_optional_string(template_id)

    Enum.find(workflow_templates(), &(Map.get(&1, "template_id") == normalized)) ||
      resolve_template(nil, trace)
  end

  defp default_template_id(trace) do
    events = Map.get(trace, :events, [])
    summary = get_in(trace, [:summary]) || %{}
    outcome = Map.get(summary, :outcome) || Map.get(summary, "outcome")

    cond do
      latest_event(events, "ExceptionRequested") -> "exception_follow_up"
      outcome in ["failed", "rejected", "deny", "denied"] -> "incident_triage"
      true -> "precedent_gap_review"
    end
  end

  defp trace_workflows(tenant_id, trace_id) do
    SQL.query_all!(
      """
      SELECT approval_event_id, assigned_account_id, assigned_role, created_from_event_id,
             current_decision, current_reason, last_action_at, last_action_type, last_source_log_seq,
             metadata_json, policy_id, policy_version, priority, requested_at, requested_by_actor_id,
             requested_by_actor_type, resolved_at, sla_due_at, status, subject_id, subject_type,
             tenant_id, title, trace_id, updated_at, workflow_id, workflow_kind, workflow_name
      FROM dg_workflow_items
      WHERE tenant_id = $1 AND trace_id = $2
      ORDER BY requested_at DESC, workflow_id ASC
      """,
      [tenant_id, trace_id]
    )
  end

  defp precedent_query_for_trace(trace) do
    summary = get_in(trace, [:summary]) || %{}
    events = Map.get(trace, :events, [])

    %{
      "entity_id" =>
        Map.get(summary, :primary_entity_id) || Map.get(summary, "primary_entity_id"),
      "entity_type" =>
        Map.get(summary, :primary_entity_type) || Map.get(summary, "primary_entity_type"),
      "limit" => 6,
      "outcome" => Map.get(summary, :outcome) || Map.get(summary, "outcome"),
      "policy_id" => template_policy_id(events),
      "policy_version" => template_policy_version(events)
    }
    |> Enum.reject(fn {_key, value} -> blank?(value) end)
    |> Map.new()
  end

  defp risk_signals(trace, precedents) do
    summary = get_in(trace, [:summary]) || %{}
    events = Map.get(trace, :events, [])
    outcome = Map.get(summary, :outcome) || Map.get(summary, "outcome")
    finished_at = Map.get(summary, :finished_at) || Map.get(summary, "finished_at")

    []
    |> maybe_push(latest_event(events, "ExceptionRequested") != nil, "exception requested")
    |> maybe_push(outcome in ["failed", "rejected", "deny", "denied"], "unfavorable outcome")
    |> maybe_push(blank?(finished_at), "trace still active")
    |> maybe_push(precedents == [], "no close precedents")
    |> maybe_push(precedent_divergence?(outcome, precedents), "precedent divergence")
  end

  defp studio_priority(trace, precedents) do
    signals = risk_signals(trace, precedents)

    cond do
      Enum.any?(signals, &(&1 in ["exception requested", "unfavorable outcome"])) -> "urgent"
      Enum.any?(signals, &(&1 in ["precedent divergence", "trace still active"])) -> "high"
      true -> "normal"
    end
  end

  defp replay_suggestion_for_trace(summary, risk_signals) do
    title = Map.get(summary, :title) || Map.get(summary, "title") || "selected trace"

    %{
      "mode" => "catch_up",
      "projection" => if(length(risk_signals) > 2, do: "all", else: "trace_summary"),
      "reason" => "workflow studio review for #{title}"
    }
  end

  defp recommended_reason(summary, template, risk_signals) do
    title = Map.get(summary, :title) || Map.get(summary, "title") || "selected trace"

    signal_text =
      if risk_signals == [], do: "operator review requested", else: Enum.join(risk_signals, ", ")

    "#{template["title"]} opened for #{title}: #{signal_text}"
  end

  defp template_policy_id(events) do
    events
    |> latest_event("PolicyEvaluated")
    |> payload_value(["payload", "policy", "policy_id"])
  end

  defp template_policy_version(events) do
    events
    |> latest_event("PolicyEvaluated")
    |> payload_value(["payload", "policy", "policy_version"])
  end

  defp latest_event(events, event_type) when is_list(events) do
    events
    |> Enum.reverse()
    |> Enum.find(&(field_value(&1, "event_type") == event_type))
  end

  defp latest_event(_events, _event_type), do: nil

  defp precedent_divergence?(current_outcome, precedents) do
    current_outcome = normalize_optional_string(current_outcome)

    precedent_outcomes =
      precedents
      |> Enum.map(&field_value(&1, "outcome"))
      |> Enum.reject(&blank?/1)
      |> Enum.uniq()

    (current_outcome != nil and length(precedent_outcomes) > 1) or
      (current_outcome != nil and precedent_outcomes != [] and
         current_outcome not in precedent_outcomes)
  end

  defp append_trace_review_request(trace_id, draft, studio, reason, tenant_id, actor, request_id) do
    trace_seq = DecisionGraph.Store.get_next_trace_seq(trace_id, tenant_id: tenant_id)
    now = SQL.now_rfc3339()
    template = Map.fetch!(studio, "template")

    attrs = %{
      "actor" => %{"actor_id" => actor.account_id, "actor_type" => "role"},
      "event_id" => "#{trace_id}-workflow-review-requested-#{trace_seq}",
      "event_type" => "WorkflowReviewRequested",
      "idempotency_key" => "workflow-review-request:#{trace_id}:#{template["template_id"]}",
      "occurred_at" => now,
      "payload" => %{
        "assignee" => %{"account_id" => nil, "role" => draft["assigned_role"]},
        "policy_id" => draft["policy_id"],
        "policy_version" => draft["policy_version"],
        "priority" => draft["priority"],
        "reason" => reason,
        "simulation" => Map.get(studio, "simulation"),
        "sla_hours" => draft["sla_hours"],
        "subject" => %{
          "subject_id" => draft["subject_id"],
          "subject_type" => draft["subject_type"]
        },
        "template_description" => template["description"],
        "template_id" => template["template_id"],
        "title" => draft["title"],
        "workflow_kind" => draft["workflow_kind"]
      },
      "source" => %{
        "producer_id" => "workflow-studio",
        "subsystem" => "workflow",
        "system" => "decisiongraph-api"
      },
      "trace_id" => trace_id,
      "trace_seq" => trace_seq
    }

    case Api.service(:events).append_event(attrs, tenant_id: tenant_id, request_id: request_id) do
      {:ok, result} ->
        audit_workflow_action("start_review", :accepted,
          account_id: actor.account_id,
          request_id: request_id,
          tenant_id: tenant_id,
          workflow_id: draft["workflow_id"]
        )

        {:ok, result}

      {:error, error} ->
        audit_workflow_action("start_review", :rejected,
          account_id: actor.account_id,
          reason: error.message,
          request_id: request_id,
          tenant_id: tenant_id,
          workflow_id: draft["workflow_id"]
        )

        {:error, error}
    end
  end

  defp run_notification_and_sla_sweep!(tenant_id, now) do
    tenant_id
    |> open_workflow_rows()
    |> Enum.each(fn item ->
      maybe_insert_deadline_risk_notification!(item, now)
      maybe_auto_escalate!(item, tenant_id, now)
    end)
  end

  defp open_workflow_rows(tenant_id) do
    SQL.query_all!(
      """
      SELECT approval_event_id, assigned_account_id, assigned_role, created_from_event_id,
             current_decision, current_reason, last_action_at, last_action_type, last_source_log_seq,
             metadata_json, policy_id, policy_version, priority, requested_at, requested_by_actor_id,
             requested_by_actor_type, resolved_at, sla_due_at, status, subject_id, subject_type,
             tenant_id, title, trace_id, updated_at, workflow_id, workflow_kind, workflow_name
      FROM dg_workflow_items
      WHERE tenant_id = $1 AND status = ANY($2)
      ORDER BY requested_at ASC, workflow_id ASC
      """,
      [tenant_id, @open_statuses]
    )
  end

  defp maybe_insert_deadline_risk_notification!(item, now) do
    warning_minutes = workflow_default(:deadline_risk_warning_minutes, 30) |> normalize_minutes()
    sla_due_at = item["sla_due_at"]

    with true <- item["status"] in @open_statuses,
         true <- present?(sla_due_at),
         {:ok, due_at, _offset} <- DateTime.from_iso8601(sla_due_at),
         {:ok, current_time, _offset} <- DateTime.from_iso8601(now),
         seconds_until_due
         when seconds_until_due > 0 and seconds_until_due <= warning_minutes * 60 <-
           DateTime.diff(due_at, current_time, :second) do
      insert_notification!(
        notification_attrs(
          item,
          "deadline_risk",
          "Workflow #{item["workflow_id"]} is nearing its SLA deadline",
          %{"sla_due_at" => sla_due_at, "warning_minutes" => warning_minutes},
          dedupe_key: "deadline_risk:#{item["workflow_id"]}:#{sla_due_at}"
        )
      )
    else
      _other -> :ok
    end
  end

  defp maybe_auto_escalate!(item, tenant_id, now) do
    if item["status"] in ["requested", "in_review", "changes_requested"] and
         present?(item["sla_due_at"]) and
         item["sla_due_at"] < now do
      escalate_workflow!(
        item,
        tenant_id,
        now,
        nil,
        "SLA deadline passed",
        "automatic_sla_escalation"
      )

      :ok
    else
      :ok
    end
  end

  defp escalate_workflow!(item, tenant_id, now, account_id, reason, source) do
    metadata = decode_json(item["metadata_json"])

    previous_assignment = %{
      "assigned_account_id" => item["assigned_account_id"],
      "assigned_role" => item["assigned_role"]
    }

    escalation_count =
      metadata |> payload_value(["escalation_count"]) |> normalize_counter() |> Kernel.+(1)

    updated_item =
      update_workflow_item!(
        item["workflow_id"],
        tenant_id,
        %{
          assigned_account_id: escalation_account_id(),
          assigned_role: escalation_role(),
          current_reason: reason,
          last_action_at: now,
          last_action_type: "escalate",
          metadata_json:
            encode_json(
              merge_workflow_metadata(item["metadata_json"], %{
                "escalated_at" => now,
                "escalation_count" => escalation_count,
                "escalation_reason" => reason,
                "previous_assignment" => previous_assignment
              })
            ),
          status: "escalated",
          updated_at: now
        }
      )

    insert_action!(
      %{
        action_type: "escalate",
        actor_account_id: account_id,
        actor_id: account_id || "workflow-sla",
        actor_type: if(account_id, do: "role", else: "system"),
        created_at: now,
        note: reason,
        payload_json:
          encode_json(%{
            "escalation_count" => escalation_count,
            "previous_assignment" => previous_assignment,
            "source" => source
          }),
        resulting_status: "escalated",
        source_event_id: nil,
        tenant_id: tenant_id,
        trace_id: item["trace_id"],
        workflow_id: item["workflow_id"]
      },
      allow_duplicates?: true
    )

    insert_notification!(
      notification_attrs(
        updated_item,
        "escalation",
        "Workflow #{item["workflow_id"]} escalated to #{assignment_target_label(updated_item)}",
        %{
          "escalation_count" => escalation_count,
          "reason" => reason,
          "source" => source
        },
        dedupe_key: "escalation:#{item["workflow_id"]}:#{escalation_count}"
      )
    )

    audit_workflow_action("escalate", :accepted,
      account_id: account_id,
      reason: reason,
      tenant_id: tenant_id,
      workflow_id: item["workflow_id"]
    )

    updated_item
  end

  defp insert_notification!(attrs) do
    notification_id = "wfn:" <> Integer.to_string(System.unique_integer([:positive]))

    SQL.execute!(
      """
      INSERT INTO dg_workflow_notifications (
        notification_id, tenant_id, workflow_id, trace_id, category, channel, status, message,
        recipient_account_id, recipient_role, payload_json, dedupe_key, created_at, delivered_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
      ON CONFLICT (tenant_id, dedupe_key) DO NOTHING
      """,
      [
        notification_id,
        attrs[:tenant_id],
        attrs[:workflow_id],
        attrs[:trace_id],
        attrs[:category],
        attrs[:channel],
        attrs[:status],
        attrs[:message],
        attrs[:recipient_account_id],
        attrs[:recipient_role],
        attrs[:payload_json],
        attrs[:dedupe_key],
        attrs[:created_at],
        attrs[:delivered_at]
      ]
    )

    :ok
  end

  defp notification_attrs(item, category, message, payload, opts) do
    timestamp = Keyword.get(opts, :created_at, SQL.now_rfc3339())

    %{
      category: category,
      channel: "operator_console",
      created_at: timestamp,
      dedupe_key: Keyword.fetch!(opts, :dedupe_key),
      delivered_at: timestamp,
      message: message,
      payload_json: encode_json(payload),
      recipient_account_id: field_value(item, "assigned_account_id"),
      recipient_role: field_value(item, "assigned_role"),
      status: "delivered",
      tenant_id: field_value(item, "tenant_id"),
      trace_id: field_value(item, "trace_id"),
      workflow_id: field_value(item, "workflow_id")
    }
  end

  defp assignment_target_label(item) do
    field_value(item, "assigned_account_id") || field_value(item, "assigned_role") || "unassigned"
  end

  defp escalation_account_id do
    workflow_default(:escalation_assigned_account_id)
    |> normalize_optional_string()
  end

  defp escalation_role do
    workflow_default(:escalation_assigned_role, "admin")
    |> normalize_optional_string()
  end

  defp field_value(map, key, default \\ nil)

  defp field_value(map, key, default) when is_map(map) do
    atom_key =
      if is_binary(key) do
        try do
          String.to_existing_atom(key)
        rescue
          ArgumentError -> nil
        end
      end

    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      atom_key && Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      true -> default
    end
  end

  defp field_value(_map, _key, default), do: default

  defp normalize_counter(value) when is_integer(value), do: value

  defp normalize_counter(value) do
    value
    |> to_string()
    |> Integer.parse()
    |> case do
      {count, ""} when count >= 0 -> count
      _other -> 0
    end
  end

  defp normalize_minutes(value) when is_integer(value) and value > 0, do: value

  defp normalize_minutes(value) do
    value
    |> to_string()
    |> Integer.parse()
    |> case do
      {minutes, ""} when minutes > 0 -> minutes
      _other -> 30
    end
  end

  defp maybe_push(list, true, value), do: list ++ [value]
  defp maybe_push(list, false, _value), do: list

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: false

  defp priority_for(payload, existing) do
    cond do
      payload["priority"] ->
        normalize_priority(payload["priority"])

      existing && present?(existing["priority"]) ->
        normalize_priority(existing["priority"])

      String.contains?(String.downcase(to_string(payload["reason"] || "")), "urgent") ->
        "urgent"

      true ->
        "high"
    end
  end

  defp add_sla_hours(timestamp) do
    hours =
      workflow_default(:exception_review_sla_hours, 4)
      |> normalize_sla_hours()

    add_hours(timestamp, hours)
  end

  defp add_hours(timestamp, hours) do
    hours = normalize_sla_hours(hours)

    with {:ok, parsed, _offset} <- DateTime.from_iso8601(timestamp) do
      parsed
      |> DateTime.add(hours * 60 * 60, :second)
      |> SQL.now_rfc3339()
    else
      _error -> timestamp
    end
  end

  defp default_assigned_account_id do
    workflow_default(:default_assigned_account_id)
    |> normalize_optional_string()
  end

  defp default_assigned_role do
    workflow_default(:default_assigned_role, "admin")
    |> normalize_optional_string()
  end

  defp workflow_default(key, default \\ nil) do
    :dg_api
    |> Application.get_env(:workflow_defaults, %{})
    |> Map.new()
    |> Map.get(key, default)
  end

  defp approval_status("override", _decision), do: "overridden"
  defp approval_status(_subject_type, "approved"), do: "approved"
  defp approval_status(_subject_type, "rejected"), do: "rejected"

  defp approval_action_type("override", _decision), do: "override"
  defp approval_action_type(_subject_type, "approved"), do: "approve"
  defp approval_action_type(_subject_type, "rejected"), do: "reject"

  defp decision_label("override", decision), do: "override_#{decision}"
  defp decision_label(_subject_type, decision), do: decision
  defp approval_decision("approve"), do: "approved"
  defp approval_decision("reject"), do: "rejected"
  defp approval_decision("override"), do: "approved"

  defp approval_idempotency_key(workflow_id, action, request_id, unique_id) do
    base = "workflow:#{workflow_id}:#{action}:#{request_id || unique_id}"

    if byte_size(base) > 190 do
      String.slice(base, 0, 190)
    else
      base
    end
  end

  defp required_reason(attrs, action) do
    case normalize_optional_string(Map.get(attrs, "reason", Map.get(attrs, :reason))) do
      nil -> raise Error, code: :invalid_argument, message: "#{action} requires a reason"
      value -> value
    end
  end

  defp normalize_action(attrs) when is_map(attrs) do
    attrs
    |> Map.get("action", Map.get(attrs, :action))
    |> normalize_required_string(:action)
    |> String.downcase()
    |> case do
      action
      when action in [
             "approve",
             "comment",
             "escalate",
             "export",
             "override",
             "reassign",
             "reject",
             "request_change"
           ] ->
        action

      other ->
        raise Error,
          code: :invalid_argument,
          message: "Unsupported workflow action #{inspect(other)}"
    end
  end

  defp normalize_filters(params) when is_map(params) do
    %{
      "assigned_account_id" =>
        normalize_optional_string(
          Map.get(params, "assigned_account_id", Map.get(params, :assigned_account_id))
        ),
      "assigned_role" =>
        normalize_optional_string(
          Map.get(params, "assigned_role", Map.get(params, :assigned_role))
        ),
      "limit" =>
        normalize_limit(Map.get(params, "limit", Map.get(params, :limit, @default_limit))),
      "only_open" =>
        normalize_boolean(Map.get(params, "only_open", Map.get(params, :only_open)), true),
      "only_overdue" =>
        normalize_boolean(Map.get(params, "only_overdue", Map.get(params, :only_overdue)), false),
      "priority" =>
        normalize_optional_string(Map.get(params, "priority", Map.get(params, :priority)))
        |> case do
          nil -> nil
          value -> normalize_priority(value)
        end,
      "status" => normalize_optional_string(Map.get(params, "status", Map.get(params, :status))),
      "trace_id" =>
        normalize_optional_string(Map.get(params, "trace_id", Map.get(params, :trace_id)))
    }
  end

  defp normalize_evidence(nil), do: []

  defp normalize_evidence(evidence) when is_list(evidence) do
    Enum.map(evidence, fn
      item when is_map(item) -> item
      item -> %{"value" => to_string(item)}
    end)
  end

  defp normalize_evidence(_evidence) do
    raise Error, code: :invalid_argument, message: "evidence must be a list when present"
  end

  defp normalize_limit(limit) when is_integer(limit) and limit > 0, do: min(limit, @max_limit)

  defp normalize_limit(limit) do
    limit
    |> to_string()
    |> Integer.parse()
    |> case do
      {value, ""} when value > 0 -> min(value, @max_limit)
      _other -> @default_limit
    end
  end

  defp normalize_boolean(nil, default), do: default
  defp normalize_boolean(value, _default) when value in [true, "true", "1", 1], do: true
  defp normalize_boolean(value, _default) when value in [false, "false", "0", 0], do: false
  defp normalize_boolean(_value, default), do: default

  defp normalize_sla_hours(value) when is_integer(value) and value > 0, do: value

  defp normalize_sla_hours(value) do
    value
    |> to_string()
    |> Integer.parse()
    |> case do
      {hours, ""} when hours > 0 -> hours
      _other -> 4
    end
  end

  defp normalize_priority(value) do
    case String.downcase(normalize_required_string(value, :priority)) do
      priority when priority in ["urgent", "high", "normal", "low"] ->
        priority

      other ->
        raise Error, code: :invalid_argument, message: "Unsupported priority #{inspect(other)}"
    end
  end

  defp normalize_tenant_id(value), do: normalize_required_string(value, :tenant_id)

  defp normalize_required_string(value, key) when is_binary(value) do
    case String.trim(value) do
      "" -> raise Error, code: :invalid_argument, message: "#{key} is required"
      normalized -> normalized
    end
  end

  defp normalize_required_string(nil, key),
    do: raise(Error, code: :invalid_argument, message: "#{key} is required")

  defp normalize_required_string(value, key),
    do: value |> to_string() |> normalize_required_string(key)

  defp normalize_optional_string(nil), do: nil

  defp normalize_optional_string(value) do
    value
    |> to_string()
    |> String.trim()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_metadata_json(nil, fallback), do: fallback
  defp normalize_metadata_json(value, _fallback) when is_binary(value), do: value
  defp normalize_metadata_json(value, _fallback) when is_map(value), do: encode_json(value)

  defp merge_workflow_metadata(nil, additions),
    do: additions |> Enum.reject(fn {_key, value} -> is_nil(value) end) |> Map.new()

  defp merge_workflow_metadata(existing, additions) do
    existing
    |> decode_json()
    |> Map.merge(additions, fn _key, left, right -> if is_nil(right), do: left, else: right end)
  end

  defp maybe_add_clause(clauses, params, nil, _sql), do: {clauses, params}
  defp maybe_add_clause(clauses, params, value, sql), do: add_clause(clauses, params, sql, value)

  defp add_clause(clauses, params, sql, value) do
    index = length(params) + 1
    {clauses ++ [replace_placeholders(sql, index)], params ++ [value]}
  end

  defp replace_placeholders(sql, start_index, count \\ 1) do
    Enum.reduce(0..(count - 1), sql, fn offset, acc ->
      String.replace(acc, "?", "$#{start_index + offset}", global: false)
    end)
  end

  defp encode_json(value), do: Jason.encode!(value || %{})
  defp decode_json(nil), do: %{}
  defp decode_json(value) when is_map(value), do: value

  defp decode_json(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded} when is_map(decoded) -> decoded
      {:ok, _decoded} -> %{}
      _error -> %{}
    end
  end

  defp payload_value(nil, _path), do: nil
  defp payload_value(value, []), do: value

  defp payload_value(map, [key | rest]) when is_map(map) do
    atom_key =
      if is_binary(key) do
        try do
          String.to_existing_atom(key)
        rescue
          ArgumentError -> nil
        end
      end

    next =
      cond do
        Map.has_key?(map, key) -> Map.get(map, key)
        atom_key && Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
        true -> nil
      end

    payload_value(next, rest)
  end

  defp payload_value(_value, _path), do: nil

  defp existing_field(item, key, default \\ nil)

  defp existing_field(nil, _key, default), do: default
  defp existing_field(map, key, default) when is_map(map), do: Map.get(map, key, default)

  defp not_found_workflow(workflow_id),
    do: Errors.from_exception(Error.new(:not_found, "Workflow not found: #{workflow_id}"))

  defp terminal_status?(status), do: status in @terminal_statuses
  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(nil), do: false
  defp present?(_value), do: true

  defp response_event_id(%{event: %{event_id: event_id}}), do: event_id
  defp response_event_id(%{"event" => %{"event_id" => event_id}}), do: event_id
  defp response_event_id(%{"event" => %{event_id: event_id}}), do: event_id
  defp response_event_id(_result), do: nil

  defp audit_workflow_action(action, outcome, opts) do
    Audit.workflow_action(action, outcome, opts)
  rescue
    _error -> :ok
  end
end
