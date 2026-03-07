defmodule DecisionGraph.Api.ReleaseDemo do
  @moduledoc false

  alias DecisionGraph.Api
  alias DecisionGraph.Domain.EventEnvelope
  alias DecisionGraph.Projector.Engine
  alias DecisionGraph.Store

  @default_tenant_id "release-demo"
  @live_exception_id "ex-live-renewal-002"
  @live_trace_id "trace-live-renewal-002"
  @incident_review_template_id "incident_triage"
  @incident_trace_id "trace-incident-review-003"
  @precedent_exception_id "ex-precedent-renewal-001"
  @precedent_trace_id "trace-precedent-renewal-001"
  @seed_profile "phase10_release_demo"

  @spec default_tenant_id() :: String.t()
  def default_tenant_id, do: @default_tenant_id

  @spec live_trace_id() :: String.t()
  def live_trace_id, do: @live_trace_id

  @spec live_workflow_id() :: String.t()
  def live_workflow_id, do: workflow_id_for(@live_trace_id, "exception", @live_exception_id)

  @spec incident_trace_id() :: String.t()
  def incident_trace_id, do: @incident_trace_id

  @spec incident_review_workflow_id() :: String.t()
  def incident_review_workflow_id do
    workflow_id_for(@incident_trace_id, "trace_review", @incident_review_template_id)
  end

  @spec precedent_trace_id() :: String.t()
  def precedent_trace_id, do: @precedent_trace_id

  @spec seed(keyword()) :: map()
  def seed(opts \\ []) do
    tenant_id = Keyword.get(opts, :tenant_id, @default_tenant_id) |> normalize_required_string()
    reset? = Keyword.get(opts, :reset, true)
    rebuild? = Keyword.get(opts, :rebuild, true)
    batch_size = Keyword.get(opts, :batch_size, 250)

    if reset? do
      :ok = Store.clear(tenant_id: tenant_id)
    end

    events = build_events()

    Enum.each(events, fn envelope ->
      Store.append_event(envelope, tenant_id: tenant_id)
    end)

    projection_results =
      if rebuild? do
        case Engine.rebuild_all(tenant_id: tenant_id, batch_size: batch_size) do
          {:ok, results} -> results
          {:error, %{error: error}} -> raise error
        end
      else
        []
      end

    {:ok, workflow_summary} = Api.service(:workflows).summary(tenant_id: tenant_id)

    {:ok, workflow_inbox} =
      Api.service(:workflows).list_inbox(
        %{"limit" => 12, "only_open" => false},
        tenant_id: tenant_id
      )

    {:ok, recent_traces} = Api.service(:traces).list_recent_traces(8, tenant_id: tenant_id)
    {:ok, live_trace} = Api.service(:traces).get_trace(@live_trace_id, tenant_id: tenant_id)

    {:ok, live_workflow} =
      Api.service(:workflows).get_workflow(live_workflow_id(), tenant_id: tenant_id)

    {:ok, review_workflow} =
      Api.service(:workflows).get_workflow(
        incident_review_workflow_id(),
        tenant_id: tenant_id
      )

    {:ok, projection_health} = Api.service(:admin).projection_health(tenant_id: tenant_id)

    {:ok, precedent_hits} =
      Api.service(:precedents).find_precedents(
        %{
          "entity_id" => "acct-acme-platform",
          "entity_type" => "account",
          "limit" => 6,
          "policy_id" => "discount-cap",
          "policy_version" => "2026.03"
        },
        tenant_id: tenant_id
      )

    console_snapshot =
      Api.service(:console).snapshot(
        tenant_id: tenant_id,
        trace_id: @live_trace_id,
        workflow_id: live_workflow_id()
      )

    %{
      api_examples: %{
        export_workflow_path: "/api/v1/admin/workflows/#{incident_review_workflow_id()}/export",
        projection_health_path: "/api/v1/projections/health",
        recent_workflows_path: "/api/v1/workflows",
        selected_trace_path: "/api/v1/traces/#{@live_trace_id}"
      },
      console_paths: %{
        default:
          operator_console_path(
            tenant_id,
            @live_trace_id,
            live_workflow_id()
          ),
        incident_review:
          operator_console_path(
            tenant_id,
            @incident_trace_id,
            incident_review_workflow_id()
          )
      },
      console_snapshot: %{
        alert_count: length(Map.get(console_snapshot, :alerts, [])),
        selected_trace_id:
          get_in(console_snapshot, [:selected_trace, :data, "summary", "trace_id"]),
        selected_workflow_id:
          get_in(console_snapshot, [:selected_workflow, :data, "workflow", "workflow_id"])
      },
      event_count: length(events),
      highlighted_traces: highlighted_traces(),
      live_trace: %{
        event_count: length(Map.get(live_trace, :events, [])),
        precedent_trace_ids: Enum.map(precedent_hits, &Map.get(&1, :trace_id)),
        trace_id: @live_trace_id,
        workflow_id: live_workflow_id(),
        workflow_status: get_in(live_workflow, [:workflow, "status"])
      },
      precedent_trace_id: @precedent_trace_id,
      projection_digests: projection_digests(projection_health),
      projection_results: Enum.map(projection_results, &projection_result_row/1),
      recent_trace_ids: Enum.map(recent_traces, &Map.get(&1, :trace_id)),
      review_workflow: %{
        trace_id: @incident_trace_id,
        workflow_id: incident_review_workflow_id(),
        workflow_status: get_in(review_workflow, [:workflow, "status"])
      },
      seed_profile: @seed_profile,
      tenant_id: tenant_id,
      workflow_inbox: %{
        item_ids: Enum.map(Map.get(workflow_inbox, :items, []), &Map.get(&1, "workflow_id")),
        open_count: get_in(workflow_summary, ["open_count"]),
        overdue_count: get_in(workflow_summary, ["overdue_count"])
      }
    }
  end

  @spec highlighted_traces() :: [map()]
  def highlighted_traces do
    [
      %{
        title: "Approved precedent",
        trace_id: @precedent_trace_id,
        workflow_id: workflow_id_for(@precedent_trace_id, "exception", @precedent_exception_id)
      },
      %{
        title: "Live exception review",
        trace_id: @live_trace_id,
        workflow_id: live_workflow_id()
      },
      %{
        title: "Incident review",
        trace_id: @incident_trace_id,
        workflow_id: incident_review_workflow_id()
      }
    ]
  end

  defp build_events do
    precedent_trace_events() ++ incident_review_trace_events() ++ live_trace_events()
  end

  defp precedent_trace_events do
    [
      event(
        @precedent_trace_id,
        0,
        "TraceStarted",
        "2026-03-06T09:00:00Z",
        %{
          "primary_entity" => %{
            "entity_id" => "acct-acme-platform",
            "entity_type" => "account",
            "system" => "crm"
          },
          "title" => "Approved renewal precedent for Acme Platform",
          "workflow" => "revenue_exception"
        }
      ),
      event(
        @precedent_trace_id,
        1,
        "InputObserved",
        "2026-03-06T09:01:00Z",
        %{
          "facts" => [
            fact("requested_discount_pct", 18),
            fact("annual_contract_value_usd", 540_000),
            fact("sales_stage", "renewal")
          ],
          "input_id" => "input:revops:precedent:001",
          "source" => %{
            "object_id" => "oppty-acme-renewal-2026-001",
            "object_type" => "opportunity",
            "system" => "crm"
          }
        }
      ),
      event(
        @precedent_trace_id,
        2,
        "EntityObserved",
        "2026-03-06T09:02:00Z",
        %{
          "entity" => %{
            "entity_id" => "contract-acme-multi-year",
            "entity_type" => "contract",
            "system" => "billing"
          },
          "facts" => [fact("term_months", 36), fact("segment", "enterprise")],
          "role" => "related"
        }
      ),
      event(
        @precedent_trace_id,
        3,
        "PolicyEvaluated",
        "2026-03-06T09:03:00Z",
        %{
          "decision" => "require_exception",
          "explanation" => %{
            "summary" => "Discount exceeds standard renewal cap but strategic value is high."
          },
          "inputs" => ["input:revops:precedent:001"],
          "policy" => %{"policy_id" => "discount-cap", "policy_version" => "2026.03"},
          "violations" => [%{"code" => "discount_threshold"}]
        },
        causation_event_id: event_id(@precedent_trace_id, "InputObserved", 1),
        source: source("policy-engine", "policy")
      ),
      event(
        @precedent_trace_id,
        4,
        "ExceptionRequested",
        "2026-03-06T09:04:00Z",
        %{
          "evidence" => [
            %{"locator" => "crm://opportunity/oppty-acme-renewal-2026-001"},
            %{"locator" => "policy://discount-cap/2026.03#threshold"}
          ],
          "exception_id" => @precedent_exception_id,
          "policy" => %{"policy_id" => "discount-cap", "policy_version" => "2026.03"},
          "reason" => "Strategic renewal needed finance approval above the standard cap."
        },
        causation_event_id: event_id(@precedent_trace_id, "PolicyEvaluated", 3),
        source: source("policy-engine", "policy")
      ),
      event(
        @precedent_trace_id,
        5,
        "ApprovalRecorded",
        "2026-03-06T09:06:00Z",
        %{
          "approval_id" => "approval:precedent:001",
          "approver" => %{"actor_id" => "finance-maya", "actor_type" => "person"},
          "decision" => "approved",
          "evidence" => [%{"locator" => "review://finance/acme-renewal-001"}],
          "reason" => "Renewal is strategic and margin floor remains acceptable.",
          "subject" => %{"subject_id" => @precedent_exception_id, "subject_type" => "exception"}
        },
        causation_event_id: event_id(@precedent_trace_id, "ExceptionRequested", 4),
        source: source("finance-review", "workflow")
      ),
      event(
        @precedent_trace_id,
        6,
        "ActionProposed",
        "2026-03-06T09:07:00Z",
        %{
          "action_id" => "action:precedent:001",
          "action_type" => "update",
          "changes" => [
            %{
              "new_value" => %{"type" => "number", "value" => 18},
              "old_value" => %{"type" => "number", "value" => 12},
              "path" => "discount_pct"
            }
          ],
          "target_entity" => %{
            "entity_id" => "oppty-acme-renewal-2026-001",
            "entity_type" => "opportunity",
            "system" => "crm"
          },
          "target_system" => "crm"
        },
        causation_event_id: event_id(@precedent_trace_id, "ApprovalRecorded", 5)
      ),
      event(
        @precedent_trace_id,
        7,
        "ActionCommitted",
        "2026-03-06T09:08:00Z",
        %{
          "action_id" => "action:precedent:001",
          "external_reference" => "crm-sync-2001",
          "status" => "success"
        },
        causation_event_id: event_id(@precedent_trace_id, "ActionProposed", 6)
      ),
      event(
        @precedent_trace_id,
        8,
        "TraceFinished",
        "2026-03-06T09:09:00Z",
        %{"outcome" => "success", "summary" => "Acme renewal approved with finance exception."},
        causation_event_id: event_id(@precedent_trace_id, "ActionCommitted", 7)
      )
    ]
  end

  defp incident_review_trace_events do
    [
      event(
        @incident_trace_id,
        0,
        "TraceStarted",
        "2026-03-07T08:30:00Z",
        %{
          "primary_entity" => %{
            "entity_id" => "acct-delta-logistics",
            "entity_type" => "account",
            "system" => "crm"
          },
          "title" => "Rejected renewal review for Delta Logistics",
          "workflow" => "revenue_exception"
        }
      ),
      event(
        @incident_trace_id,
        1,
        "InputObserved",
        "2026-03-07T08:31:00Z",
        %{
          "facts" => [
            fact("requested_discount_pct", 26),
            fact("annual_contract_value_usd", 110_000),
            fact("sales_stage", "renewal")
          ],
          "input_id" => "input:revops:incident:003",
          "source" => %{
            "object_id" => "oppty-delta-renewal-2026-003",
            "object_type" => "opportunity",
            "system" => "crm"
          }
        }
      ),
      event(
        @incident_trace_id,
        2,
        "PolicyEvaluated",
        "2026-03-07T08:32:00Z",
        %{
          "decision" => "require_exception",
          "explanation" => %{
            "summary" => "Requested discount exceeds guardrail and precedent confidence is weak."
          },
          "inputs" => ["input:revops:incident:003"],
          "policy" => %{"policy_id" => "discount-cap", "policy_version" => "2026.03"},
          "violations" => [%{"code" => "discount_threshold"}]
        },
        causation_event_id: event_id(@incident_trace_id, "InputObserved", 1),
        source: source("policy-engine", "policy")
      ),
      event(
        @incident_trace_id,
        3,
        "ExceptionRequested",
        "2026-03-07T08:33:00Z",
        %{
          "evidence" => [%{"locator" => "crm://opportunity/oppty-delta-renewal-2026-003"}],
          "exception_id" => "ex-incident-review-003",
          "policy" => %{"policy_id" => "discount-cap", "policy_version" => "2026.03"},
          "reason" => "Sales requested a discount above policy for a price-sensitive renewal."
        },
        causation_event_id: event_id(@incident_trace_id, "PolicyEvaluated", 2),
        source: source("policy-engine", "policy")
      ),
      event(
        @incident_trace_id,
        4,
        "ApprovalRecorded",
        "2026-03-07T08:36:00Z",
        %{
          "approval_id" => "approval:incident:003",
          "approver" => %{"actor_id" => "finance-owen", "actor_type" => "person"},
          "decision" => "rejected",
          "reason" => "Margin would fall below the approved floor for this account.",
          "subject" => %{"subject_id" => "ex-incident-review-003", "subject_type" => "exception"}
        },
        causation_event_id: event_id(@incident_trace_id, "ExceptionRequested", 3),
        source: source("finance-review", "workflow")
      ),
      event(
        @incident_trace_id,
        5,
        "WorkflowReviewRequested",
        "2026-03-07T08:37:00Z",
        %{
          "assignee" => %{"account_id" => nil, "role" => "admin"},
          "priority" => "high",
          "reason" =>
            "Review why the Delta renewal could not be approved and capture operator guidance.",
          "simulation" => %{
            "current_outcome" => "failure",
            "precedent_trace_ids" => [@precedent_trace_id],
            "risk_signals" => ["rejected_exception", "high_discount"]
          },
          "sla_hours" => 6,
          "subject" => %{
            "subject_id" => @incident_review_template_id,
            "subject_type" => "trace_review"
          },
          "template_id" => @incident_review_template_id,
          "title" => "Incident review for Delta Logistics rejection",
          "workflow_kind" => "incident_review"
        },
        causation_event_id: event_id(@incident_trace_id, "ApprovalRecorded", 4),
        source: source("operator-console", "workflow")
      ),
      event(
        @incident_trace_id,
        6,
        "TraceFinished",
        "2026-03-07T08:38:00Z",
        %{"outcome" => "failure", "summary" => "Delta renewal rejected after finance review."},
        causation_event_id: event_id(@incident_trace_id, "WorkflowReviewRequested", 5)
      )
    ]
  end

  defp live_trace_events do
    [
      event(
        @live_trace_id,
        0,
        "TraceStarted",
        "2026-03-07T10:00:00Z",
        %{
          "primary_entity" => %{
            "entity_id" => "acct-acme-platform",
            "entity_type" => "account",
            "system" => "crm"
          },
          "title" => "Live renewal exception review for Acme Platform",
          "workflow" => "revenue_exception"
        }
      ),
      event(
        @live_trace_id,
        1,
        "InputObserved",
        "2026-03-07T10:01:00Z",
        %{
          "facts" => [
            fact("requested_discount_pct", 21),
            fact("annual_contract_value_usd", 620_000),
            fact("sales_stage", "renewal")
          ],
          "input_id" => "input:revops:live:002",
          "source" => %{
            "object_id" => "oppty-acme-renewal-2026-002",
            "object_type" => "opportunity",
            "system" => "crm"
          }
        }
      ),
      event(
        @live_trace_id,
        2,
        "EntityObserved",
        "2026-03-07T10:02:00Z",
        %{
          "entity" => %{
            "entity_id" => "quote-acme-renewal-2026-002",
            "entity_type" => "quote",
            "system" => "quoting"
          },
          "facts" => [fact("quote_status", "needs_exception"), fact("currency", "USD")],
          "role" => "related"
        }
      ),
      event(
        @live_trace_id,
        3,
        "PolicyEvaluated",
        "2026-03-07T10:03:00Z",
        %{
          "decision" => "require_exception",
          "explanation" => %{
            "summary" =>
              "Discount is above the standard cap but historical enterprise renewals suggest approval is possible."
          },
          "inputs" => ["input:revops:live:002"],
          "policy" => %{"policy_id" => "discount-cap", "policy_version" => "2026.03"},
          "violations" => [%{"code" => "discount_threshold"}]
        },
        causation_event_id: event_id(@live_trace_id, "InputObserved", 1),
        source: source("policy-engine", "policy")
      ),
      event(
        @live_trace_id,
        4,
        "ExceptionRequested",
        "2026-03-07T10:04:00Z",
        %{
          "evidence" => [
            %{"locator" => "crm://opportunity/oppty-acme-renewal-2026-002"},
            %{"locator" => "quote://quote-acme-renewal-2026-002"}
          ],
          "exception_id" => @live_exception_id,
          "policy" => %{"policy_id" => "discount-cap", "policy_version" => "2026.03"},
          "reason" => "Strategic enterprise renewal requires manual review above the cap."
        },
        causation_event_id: event_id(@live_trace_id, "PolicyEvaluated", 3),
        source: source("policy-engine", "policy")
      ),
      event(
        @live_trace_id,
        5,
        "PrecedentCited",
        "2026-03-07T10:05:00Z",
        %{
          "cited_trace_id" => @precedent_trace_id,
          "reason" => "Matches strategic renewal posture with a similar approved exception.",
          "similarity_score" => "0.92"
        },
        causation_event_id: event_id(@live_trace_id, "ExceptionRequested", 4),
        source: source("precedent-engine", "query")
      )
    ]
  end

  defp projection_result_row(result) do
    %{
      last_log_seq: result.last_log_seq,
      pending_events: result.pending_events,
      processed_events: result.processed_events,
      projection_name: result.projection_name,
      tenant_id: result.tenant_id
    }
  end

  defp projection_digests(projection_health) do
    projection_health
    |> Map.get(:projections, [])
    |> Enum.map(fn projection ->
      {projection.projection_name |> to_string(), projection.digest}
    end)
    |> Enum.reject(fn {_projection_name, digest} -> is_nil(digest) end)
    |> Map.new()
    |> Map.put("full_projection", Map.get(projection_health, :full_digest))
  end

  defp operator_console_path(tenant_id, trace_id, workflow_id) do
    "/?tenant=#{tenant_id}&trace_id=#{trace_id}&workflow_id=#{workflow_id}"
  end

  defp fact(key, value) when is_binary(value) do
    %{
      "as_of" => "2026-03-07T10:00:00Z",
      "key" => key,
      "value" => %{"type" => "string", "value" => value}
    }
  end

  defp fact(key, value) when is_integer(value) do
    %{
      "as_of" => "2026-03-07T10:00:00Z",
      "key" => key,
      "value" => %{"type" => "number", "value" => value}
    }
  end

  defp event(trace_id, trace_seq, event_type, occurred_at, payload, opts \\ []) do
    source = Keyword.get(opts, :source, source("release-demo", "seed"))
    actor = Keyword.get(opts, :actor, actor("system", "phase10-seeder"))

    EventEnvelope.new(%{
      actor: actor,
      causation_event_id: Keyword.get(opts, :causation_event_id),
      correlation_id: "phase10:#{trace_id}",
      event_id: Keyword.get(opts, :event_id, event_id(trace_id, event_type, trace_seq)),
      event_type: event_type,
      idempotency_key:
        Keyword.get(opts, :idempotency_key, idempotency_key(trace_id, event_type, trace_seq)),
      occurred_at: occurred_at,
      payload: payload,
      source: source,
      tags: ["phase10", "release-demo"],
      trace_id: trace_id,
      trace_seq: trace_seq
    })
  end

  defp workflow_id_for(trace_id, subject_type, subject_id) do
    "#{trace_id}:#{subject_type}:#{subject_id}"
  end

  defp event_id(trace_id, event_type, trace_seq) do
    "#{trace_id}-#{Macro.underscore(event_type)}-#{trace_seq}"
  end

  defp idempotency_key(trace_id, event_type, trace_seq) do
    "#{String.downcase(event_type)}:#{trace_id}:#{trace_seq}"
  end

  defp actor(actor_type, actor_id) do
    %{"actor_id" => actor_id, "actor_type" => actor_type}
  end

  defp source(producer_id, subsystem) do
    %{"producer_id" => producer_id, "subsystem" => subsystem, "system" => "decisiongraph"}
  end

  defp normalize_required_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> raise ArgumentError, "tenant_id is required"
      normalized -> normalized
    end
  end

  defp normalize_required_string(nil), do: raise(ArgumentError, "tenant_id is required")
  defp normalize_required_string(value), do: value |> to_string() |> normalize_required_string()
end
