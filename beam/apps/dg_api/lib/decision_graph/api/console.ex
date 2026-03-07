defmodule DecisionGraph.Api.Console do
  @moduledoc false

  alias DecisionGraph.Api
  alias DecisionGraph.Api.{Errors, Serialization, ServiceAccount}

  @default_event_limit 12
  @default_failure_limit 5
  @default_recent_limit 8
  @default_run_limit 8
  @default_workflow_limit 8

  @policy_event_types [
    "PolicyEvaluated",
    "ExceptionRequested",
    "ApprovalRecorded",
    "ActionProposed",
    "ActionCommitted",
    "TraceFinished"
  ]

  @spec snapshot(keyword()) :: map()
  def snapshot(opts \\ []) do
    tenant_id = normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))
    recent_limit = normalize_recent_limit(Keyword.get(opts, :recent_limit, @default_recent_limit))
    event_limit = normalize_event_limit(Keyword.get(opts, :event_limit, @default_event_limit))
    replay_limit = normalize_run_limit(Keyword.get(opts, :run_limit, @default_run_limit))

    workflow_limit =
      normalize_run_limit(Keyword.get(opts, :workflow_limit, @default_workflow_limit))

    failure_limit =
      normalize_failure_limit(Keyword.get(opts, :failure_limit, @default_failure_limit))

    projector = serialize_data(DecisionGraph.Projector.runtime_snapshot())
    store = serialize_data(DecisionGraph.Store.deployment_snapshot())
    console_controls = console_controls_section()
    projection_health = projection_health_section(tenant_id)
    recent_traces = recent_traces_section(tenant_id, recent_limit)

    trace_id =
      Keyword.get(opts, :trace_id)
      |> normalize_optional_string()
      |> case do
        nil -> first_recent_trace_id(recent_traces)
        selected_trace_id -> selected_trace_id
      end

    selected_trace = selected_trace_section(tenant_id, trace_id)
    workflow_inbox = workflow_inbox_section(tenant_id, workflow_limit)

    workflow_id =
      Keyword.get(opts, :workflow_id)
      |> normalize_optional_string()
      |> case do
        nil -> first_workflow_id(workflow_inbox, trace_id)
        selected_workflow_id -> selected_workflow_id
      end

    selected_workflow = selected_workflow_section(tenant_id, workflow_id)
    context_graph = context_graph_section(tenant_id, selected_trace)
    policy_review = policy_review_section(selected_trace)
    precedents = precedents_section(tenant_id, selected_trace)
    review_studio = review_studio_section(tenant_id, selected_trace)
    event_stream = event_stream_section(tenant_id, event_limit)

    replay_console =
      replay_console_section(
        tenant_id,
        projection_health,
        console_controls,
        replay_limit,
        failure_limit
      )

    tenant_status = tenant_status_section(tenant_id)
    environment_status = environment_status_section(projector, store, projection_health)

    %{
      alerts:
        alerts_for(
          console_controls,
          projection_health,
          selected_trace,
          workflow_inbox,
          selected_workflow,
          context_graph,
          precedents,
          review_studio,
          replay_console
        ),
      console_controls: console_controls,
      context_graph: context_graph,
      deployment_env: Application.get_env(:dg_api, :deployment_env, "dev"),
      environment_status: environment_status,
      event_stream: event_stream,
      policy_review: policy_review,
      precedents: precedents,
      projection_health: projection_health,
      recent_traces: recent_traces,
      refreshed_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
      replay_console: replay_console,
      review_studio: review_studio,
      selected_trace: selected_trace,
      selected_workflow: selected_workflow,
      store: store,
      tenant_id: tenant_id,
      tenant_status: tenant_status,
      workflow_inbox: workflow_inbox,
      projector: projector
    }
  end

  @spec start_replay(map(), keyword()) ::
          {:ok, map()} | {:error, DecisionGraph.Api.HttpError.t()}
  def start_replay(attrs, opts \\ []) do
    tenant_id = normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))

    with {:ok, actor} <- operator_actor_result(),
         {:ok, run} <-
           Api.service(:admin).start_replay(
             attrs,
             tenant_id: tenant_id,
             actor: actor,
             request_id: operator_request_id("replay")
           ) do
      {:ok, serialize_data(run)}
    end
  rescue
    error -> {:error, Errors.from_exception(error)}
  end

  @spec cancel_replay(String.t(), keyword()) ::
          {:ok, map()} | {:error, DecisionGraph.Api.HttpError.t()}
  def cancel_replay(job_id, opts \\ []) do
    tenant_id = normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))

    with {:ok, actor} <- operator_actor_result(),
         {:ok, run} <-
           Api.service(:admin).cancel_replay(
             job_id,
             tenant_id: tenant_id,
             actor: actor,
             request_id: operator_request_id("cancel")
           ) do
      {:ok, serialize_data(run)}
    end
  rescue
    error -> {:error, Errors.from_exception(error)}
  end

  @spec act_on_workflow(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, DecisionGraph.Api.HttpError.t()}
  def act_on_workflow(workflow_id, attrs, opts \\ []) do
    tenant_id = normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))

    with {:ok, actor} <- operator_actor_result(),
         {:ok, result} <-
           Api.service(:workflows).act_on_workflow(
             workflow_id,
             attrs,
             tenant_id: tenant_id,
             actor: actor,
             request_id: operator_request_id("workflow")
           ) do
      {:ok, serialize_data(result)}
    end
  rescue
    error -> {:error, Errors.from_exception(error)}
  end

  @spec export_workflow(String.t(), keyword()) ::
          {:ok, map()} | {:error, DecisionGraph.Api.HttpError.t()}
  def export_workflow(workflow_id, opts \\ []) do
    tenant_id = normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))

    with {:ok, actor} <- operator_actor_result(),
         {:ok, result} <-
           Api.service(:workflows).export_workflow(
             workflow_id,
             tenant_id: tenant_id,
             actor: actor
           ) do
      {:ok, serialize_data(result)}
    end
  rescue
    error -> {:error, Errors.from_exception(error)}
  end

  @spec start_trace_review(String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, DecisionGraph.Api.HttpError.t()}
  def start_trace_review(trace_id, attrs, opts \\ []) do
    tenant_id = normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))

    with {:ok, actor} <- operator_actor_result(),
         {:ok, result} <-
           Api.service(:workflow_studio).start_review(
             trace_id,
             attrs,
             tenant_id: tenant_id,
             actor: actor,
             request_id: operator_request_id("review")
           ) do
      {:ok, serialize_data(result)}
    end
  rescue
    error -> {:error, Errors.from_exception(error)}
  end

  defp console_controls_section do
    case Api.operator_console_actor() do
      %ServiceAccount{} = actor ->
        %{
          data:
            serialize_data(%{
              account_id: actor.account_id,
              actions_enabled: true,
              can_rebuild: ServiceAccount.allows?(actor, "projection_rebuild"),
              can_replay: ServiceAccount.allows?(actor, "projection_replay"),
              can_workflow_assign: ServiceAccount.allows?(actor, "workflow_assign"),
              can_workflow_escalate: ServiceAccount.allows?(actor, "workflow_escalate"),
              can_workflow_export: ServiceAccount.allows?(actor, "workflow_export"),
              can_workflow_override: ServiceAccount.allows?(actor, "workflow_override"),
              can_workflow_review: ServiceAccount.allows?(actor, "workflow_review"),
              permissions: actor.permissions,
              roles: actor.roles,
              tenant_ids: actor.tenant_ids
            }),
          error: nil,
          status: "ready"
        }

      nil ->
        %{
          data:
            serialize_data(%{
              account_id: nil,
              actions_enabled: false,
              can_rebuild: false,
              can_replay: false,
              can_workflow_assign: false,
              can_workflow_escalate: false,
              can_workflow_export: false,
              can_workflow_override: false,
              can_workflow_review: false,
              permissions: [],
              roles: [],
              tenant_ids: []
            }),
          error:
            "Replay controls stay disabled until :dg_api operator_console_account_id or operator_console_actor is configured.",
          status: "disabled"
        }
    end
  end

  defp projection_health_section(tenant_id) do
    case Api.service(:admin).projection_health(tenant_id: tenant_id) do
      {:ok, health} ->
        serialized = serialize_data(health)

        %{
          data: serialized,
          error: nil,
          status: "ready",
          summary: %{
            open_failures:
              serialized
              |> Map.get("projections", [])
              |> Enum.reduce(0, &(field_integer(&1, "open_failures") + &2)),
            open_runs: serialized |> Map.get("open_runs", []) |> length(),
            pending_events:
              serialized
              |> Map.get("projections", [])
              |> Enum.reduce(0, &(field_integer(&1, "pending_events") + &2)),
            projection_count: serialized |> Map.get("projections", []) |> length(),
            stale_count:
              serialized
              |> Map.get("projections", [])
              |> Enum.count(&truthy_field?(&1, "is_stale"))
          }
        }

      {:error, error} ->
        %{
          data: nil,
          error: error.message,
          status: "unavailable",
          summary: %{
            open_failures: 0,
            open_runs: 0,
            pending_events: 0,
            projection_count: 0,
            stale_count: 0
          }
        }
    end
  end

  defp recent_traces_section(tenant_id, limit) do
    case Api.service(:traces).list_recent_traces(limit, tenant_id: tenant_id) do
      {:ok, traces} ->
        %{
          error: nil,
          items: serialize_data(traces),
          status: "ready"
        }

      {:error, error} ->
        %{
          error: error.message,
          items: [],
          status: "unavailable"
        }
    end
  end

  defp workflow_inbox_section(tenant_id, limit) do
    case Api.service(:workflows).list_inbox(%{"limit" => limit}, tenant_id: tenant_id) do
      {:ok, inbox} ->
        serialized = serialize_data(inbox)

        %{
          data: serialized,
          error: nil,
          status: "ready",
          summary: Map.get(serialized, "summary", %{})
        }

      {:error, error} ->
        %{
          data: nil,
          error: error.message,
          status: "unavailable",
          summary: %{
            "open_count" => 0,
            "overdue_count" => 0,
            "requested_count" => 0
          }
        }
    end
  end

  defp selected_workflow_section(_tenant_id, nil) do
    %{
      data: nil,
      error: "Select a workflow item to inspect assignment, comments, and approval state.",
      status: "empty",
      workflow_id: nil
    }
  end

  defp selected_workflow_section(tenant_id, workflow_id) do
    case Api.service(:workflows).get_workflow(workflow_id, tenant_id: tenant_id) do
      {:ok, workflow} ->
        serialized = serialize_data(workflow)

        %{
          data: serialized,
          error: nil,
          status: "ready",
          workflow_id: workflow_id
        }

      {:error, error} ->
        %{
          data: nil,
          error: error.message,
          status: "unavailable",
          workflow_id: workflow_id
        }
    end
  end

  defp selected_trace_section(_tenant_id, nil) do
    %{
      data: nil,
      error: "Select a trace to inspect its timeline and payloads.",
      status: "empty",
      trace_id: nil
    }
  end

  defp selected_trace_section(tenant_id, trace_id) do
    case Api.service(:traces).get_trace(trace_id, tenant_id: tenant_id) do
      {:ok, trace} ->
        serialized = serialize_data(trace)

        %{
          data: Map.put(serialized, "investigator_handoff", investigator_handoff(serialized)),
          error: nil,
          status: "ready",
          trace_id: trace_id
        }

      {:error, error} ->
        %{
          data: nil,
          error: error.message,
          status: "unavailable",
          trace_id: trace_id
        }
    end
  end

  defp context_graph_section(_tenant_id, %{status: "empty"} = trace) do
    %{
      data: nil,
      error: trace.error || "Select a trace to visualize its context graph.",
      status: "empty"
    }
  end

  defp context_graph_section(_tenant_id, %{status: "unavailable"} = trace) do
    %{
      data: nil,
      error: trace.error || "The selected trace could not be loaded.",
      status: "unavailable"
    }
  end

  defp context_graph_section(tenant_id, trace) do
    trace_id = get_in(trace, [:data, "summary", "trace_id"])

    case Api.service(:graph).get_context_subgraph(
           %{
             "max_depth" => 2,
             "max_edges" => 24,
             "max_nodes" => 24,
             "node_id" => trace_id,
             "node_type" => "trace"
           },
           tenant_id: tenant_id
         ) do
      {:ok, graph} ->
        serialized = serialize_data(graph)

        %{
          data:
            Map.merge(serialized, %{
              "center_trace_id" => trace_id,
              "node_count" => length(Map.get(serialized, "nodes", [])),
              "edge_count" => length(Map.get(serialized, "edges", []))
            }),
          error: nil,
          status: "ready"
        }

      {:error, error} ->
        %{
          data: nil,
          error: error.message,
          status: "unavailable"
        }
    end
  rescue
    error ->
      %{
        data: nil,
        error: Exception.message(error),
        status: "unavailable"
      }
  end

  defp precedents_section(_tenant_id, %{status: "empty"} = trace) do
    %{
      data: nil,
      error: trace.error || "Select a trace to load precedent context.",
      status: "empty"
    }
  end

  defp precedents_section(_tenant_id, %{status: "unavailable"} = trace) do
    %{
      data: nil,
      error: trace.error || "The selected trace could not be loaded.",
      status: "unavailable"
    }
  end

  defp precedents_section(tenant_id, trace) do
    summary = get_in(trace, [:data, "summary"]) || %{}
    policy = trace_policy(trace)
    query = precedent_query(summary, policy)

    case Api.service(:precedents).find_precedents(query, tenant_id: tenant_id) do
      {:ok, precedents} ->
        items =
          precedents
          |> serialize_data()
          |> Enum.reject(&(Map.get(&1, "trace_id") == Map.get(summary, "trace_id")))

        %{
          data: %{
            "focus" =>
              serialize_data(%{
                entity_id: Map.get(summary, "primary_entity_id"),
                entity_type: Map.get(summary, "primary_entity_type"),
                outcome: Map.get(summary, "outcome"),
                policy: policy,
                trace_id: Map.get(summary, "trace_id")
              }),
            "items" => items
          },
          error:
            if(items == [],
              do: "No matching precedents surfaced for the current trace.",
              else: nil
            ),
          status: if(items == [], do: "empty", else: "ready")
        }

      {:error, error} ->
        %{
          data: nil,
          error: error.message,
          status: "unavailable"
        }
    end
  rescue
    error ->
      %{
        data: nil,
        error: Exception.message(error),
        status: "unavailable"
      }
  end

  defp review_studio_section(_tenant_id, %{status: "empty"} = trace) do
    %{
      data: nil,
      error: trace.error || "Select a trace to simulate or start an incident review.",
      status: "empty"
    }
  end

  defp review_studio_section(_tenant_id, %{status: "unavailable"} = trace) do
    %{
      data: nil,
      error: trace.error || "The selected trace could not be loaded.",
      status: "unavailable"
    }
  end

  defp review_studio_section(tenant_id, trace) do
    trace_id = get_in(trace, [:data, "summary", "trace_id"])

    case Api.service(:workflow_studio).overview(trace_id, %{}, tenant_id: tenant_id) do
      {:ok, studio} ->
        %{
          data: serialize_data(studio),
          error: nil,
          status: "ready"
        }

      {:error, error} ->
        %{
          data: nil,
          error: error.message,
          status: "unavailable"
        }
    end
  rescue
    error ->
      %{
        data: nil,
        error: Exception.message(error),
        status: "unavailable"
      }
  end

  defp policy_review_section(%{status: "empty"} = trace) do
    %{
      data: nil,
      error: trace.error || "Select a trace to inspect policy and approval context.",
      status: "empty"
    }
  end

  defp policy_review_section(%{status: "unavailable"} = trace) do
    %{
      data: nil,
      error: trace.error || "The selected trace could not be loaded.",
      status: "unavailable"
    }
  end

  defp policy_review_section(trace) do
    summary = get_in(trace, [:data, "summary"]) || %{}
    events = get_in(trace, [:data, "events"]) || []
    policy_event = latest_event(events, "PolicyEvaluated")
    exception_event = latest_event(events, "ExceptionRequested")
    approval_event = latest_event(events, "ApprovalRecorded")
    action_proposed = latest_event(events, "ActionProposed")
    action_committed = latest_event(events, "ActionCommitted")
    policy = trace_policy(trace)

    timeline =
      events
      |> Enum.filter(&(Map.get(&1, "event_type") in @policy_event_types))
      |> Enum.map(fn event ->
        %{
          actor: Map.get(event, "actor"),
          event_id: Map.get(event, "event_id"),
          event_type: Map.get(event, "event_type"),
          occurred_at: Map.get(event, "occurred_at"),
          summary: policy_event_summary(event)
        }
      end)

    serialized =
      serialize_data(%{
        action: %{
          action_id:
            payload_value(action_committed, ["action_id"]) ||
              payload_value(action_proposed, ["action_id"]),
          committed_at: Map.get(action_committed || %{}, "occurred_at"),
          proposed_at: Map.get(action_proposed || %{}, "occurred_at"),
          status:
            cond do
              action_committed -> "committed"
              action_proposed -> "proposed"
              true -> "pending"
            end,
          target_entity: payload_value(action_proposed, ["target_entity"])
        },
        approval: %{
          actor:
            payload_value(approval_event, ["approver"]) || Map.get(approval_event || %{}, "actor"),
          decision:
            payload_value(approval_event, ["decision"]) ||
              payload_value(approval_event, ["outcome"]) ||
              payload_value(approval_event, ["status"]) ||
              "pending",
          occurred_at: Map.get(approval_event || %{}, "occurred_at"),
          rationale:
            payload_value(approval_event, ["rationale"]) ||
              payload_value(approval_event, ["reason"]) ||
              payload_value(approval_event, ["note"])
        },
        exception: %{
          exception_id:
            payload_value(exception_event, ["exception_id"]) ||
              payload_value(approval_event, ["subject", "subject_id"]),
          occurred_at: Map.get(exception_event || %{}, "occurred_at"),
          rationale:
            payload_value(exception_event, ["reason"]) ||
              payload_value(exception_event, ["rationale"]) ||
              payload_value(exception_event, ["summary"]),
          status:
            cond do
              approval_event -> "reviewed"
              exception_event -> "requested"
              true -> "not_required"
            end
        },
        explanation:
          payload_value(policy_event, ["explanation", "summary"]) ||
            payload_value(policy_event, ["explanation"]) ||
            payload_value(policy_event, ["summary"]),
        outcome:
          Map.get(summary, "outcome") || payload_value(policy_event, ["decision"]) || "pending",
        policy:
          Map.merge(policy, %{
            "decision" =>
              payload_value(policy_event, ["decision"]) ||
                payload_value(policy_event, ["outcome"]),
            "evaluated_at" => Map.get(policy_event || %{}, "occurred_at")
          }),
        timeline: timeline,
        trace_id: Map.get(summary, "trace_id"),
        workflow: Map.get(summary, "workflow")
      })

    %{
      data: serialized,
      error: nil,
      status: "ready"
    }
  end

  defp event_stream_section(tenant_id, limit) do
    case Api.service(:traces).list_recent_events(limit, tenant_id: tenant_id) do
      {:ok, events} ->
        %{
          error: nil,
          items: serialize_data(events),
          status: "ready"
        }

      {:error, error} ->
        %{
          error: error.message,
          items: [],
          status: "unavailable"
        }
    end
  end

  defp replay_console_section(
         tenant_id,
         projection_health,
         console_controls,
         run_limit,
         failure_limit
       ) do
    runs_result = Api.service(:admin).list_runs(tenant_id: tenant_id)
    failures_result = Api.service(:admin).list_failures(tenant_id: tenant_id)

    runs =
      case runs_result do
        {:ok, items} -> items |> serialize_data() |> Enum.take(run_limit)
        {:error, _error} -> []
      end

    failures =
      case failures_result do
        {:ok, items} -> items |> serialize_data() |> Enum.take(failure_limit)
        {:error, _error} -> []
      end

    projection_digests =
      projection_health
      |> Map.get(:data, %{})
      |> Map.get("projections", [])
      |> Enum.map(fn projection ->
        %{
          "digest" => Map.get(projection, "digest"),
          "last_log_seq" => Map.get(projection, "last_log_seq"),
          "open_failures" => Map.get(projection, "open_failures", 0),
          "pending_events" => Map.get(projection, "pending_events", 0),
          "projection_name" => Map.get(projection, "projection_name")
        }
      end)

    error_messages =
      [runs_result, failures_result]
      |> Enum.flat_map(fn
        {:error, error} -> [error.message]
        _other -> []
      end)

    %{
      data: %{
        "controls" => Map.get(console_controls, :data, %{}),
        "full_digest" => get_in(projection_health, [:data, "full_digest"]),
        "latest_failures" => failures,
        "projection_digests" => projection_digests,
        "runs" => runs
      },
      error:
        case error_messages do
          [] -> nil
          messages -> Enum.join(messages, " ")
        end,
      status:
        if(error_messages == [] or runs != [] or failures != [] or projection_digests != [],
          do: "ready",
          else: "unavailable"
        )
    }
  end

  defp tenant_status_section(tenant_id) do
    case Api.service(:traces).tenant_overview(tenant_id: tenant_id) do
      {:ok, overview} ->
        %{
          data: serialize_data(overview),
          error: nil,
          status: "ready"
        }

      {:error, error} ->
        %{
          data: nil,
          error: error.message,
          status: "unavailable"
        }
    end
  end

  defp environment_status_section(projector, store, projection_health) do
    %{
      data: %{
        "active_replay_jobs" => Map.get(projector, "active_replay_jobs", 0),
        "active_workers" => Map.get(projector, "active_workers", 0),
        "database" => Map.get(store, "database"),
        "deployment_env" => Application.get_env(:dg_api, :deployment_env, "dev"),
        "event_log_last_seq" => get_in(projection_health, [:data, "event_log_last_seq"]),
        "hostname" => Map.get(store, "hostname"),
        "partition_count" => Map.get(projector, "partition_count", 0),
        "pool_size" => Map.get(store, "pool_size"),
        "projection_batch_size" =>
          Application.get_env(:dg_projector, :projection_batch_size, 250),
        "projection_job_batch_size" =>
          Application.get_env(:dg_projector, :projection_job_batch_size, 500),
        "projection_poll_interval_ms" =>
          Application.get_env(:dg_projector, :projection_poll_interval_ms, 1_000),
        "projections" => Map.get(projector, "projections", []),
        "repo_started?" => Map.get(store, "repo_started?", false)
      },
      error: nil,
      status: "ready"
    }
  end

  defp alerts_for(
         console_controls,
         projection_health,
         selected_trace,
         workflow_inbox,
         selected_workflow,
         context_graph,
         precedents,
         review_studio,
         replay_console
       ) do
    []
    |> maybe_add_alert(
      get_in(console_controls, [:data, "actions_enabled"]) == false,
      "info",
      "Replay actions disabled",
      console_controls.error
    )
    |> maybe_add_alert(
      projection_health.summary.open_failures > 0,
      "alert",
      "Projection failures need review",
      "#{projection_health.summary.open_failures} open failures are blocking clean operator posture."
    )
    |> maybe_add_alert(
      projection_health.summary.stale_count > 0,
      "warn",
      "Projection lag detected",
      "#{projection_health.summary.stale_count} projections are still catching up with the event log."
    )
    |> maybe_add_alert(
      selected_trace.status == "unavailable",
      "warn",
      "Selected trace unavailable",
      selected_trace.error
    )
    |> maybe_add_alert(
      workflow_inbox.status == "unavailable",
      "warn",
      "Workflow inbox degraded",
      workflow_inbox.error
    )
    |> maybe_add_alert(
      get_in(workflow_inbox, [:summary, "overdue_count"]) > 0,
      "alert",
      "Workflow SLA risk detected",
      "#{get_in(workflow_inbox, [:summary, "overdue_count"])} workflow items are overdue."
    )
    |> maybe_add_alert(
      selected_workflow.status == "unavailable",
      "warn",
      "Selected workflow unavailable",
      selected_workflow.error
    )
    |> maybe_add_alert(
      context_graph.status == "unavailable",
      "warn",
      "Context graph degraded",
      context_graph.error
    )
    |> maybe_add_alert(
      precedents.status == "unavailable",
      "warn",
      "Precedent search degraded",
      precedents.error
    )
    |> maybe_add_alert(
      review_studio.status == "unavailable",
      "warn",
      "Workflow studio degraded",
      review_studio.error
    )
    |> maybe_add_alert(
      replay_console.error not in [nil, ""],
      "warn",
      "Replay console partial",
      replay_console.error
    )
  end

  defp investigator_handoff(%{"events" => events, "summary" => summary}) do
    policy = trace_policy_from_events(events)
    approval = latest_event(events, "ApprovalRecorded")
    exception = latest_event(events, "ExceptionRequested")

    [
      "trace_id=#{Map.get(summary, "trace_id")}",
      "workflow=#{Map.get(summary, "workflow") || "unknown"}",
      "entity=#{entity_label(summary)}",
      "outcome=#{Map.get(summary, "outcome") || "pending"}",
      "policy=#{Map.get(policy, "policy_id") || "unknown"}@#{Map.get(policy, "policy_version") || "n/a"}",
      "exception_id=#{payload_value(exception, ["exception_id"]) || "none"}",
      "approval=#{payload_value(approval, ["decision"]) || payload_value(approval, ["status"]) || "pending"}",
      "events=#{Map.get(summary, "event_count") || length(events)}"
    ]
    |> Enum.join("\n")
  end

  defp investigator_handoff(_trace), do: nil

  defp precedent_query(summary, policy) do
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

  defp trace_policy(trace) do
    trace
    |> get_in([:data, "events"])
    |> trace_policy_from_events()
  end

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

  defp latest_event(events, event_type) when is_list(events) do
    events
    |> Enum.reverse()
    |> Enum.find(&(Map.get(&1, "event_type") == event_type))
  end

  defp latest_event(_events, _event_type), do: nil

  defp policy_event_summary(event) when is_map(event) do
    payload = Map.get(event, "payload") || %{}

    case Map.get(event, "event_type") do
      "PolicyEvaluated" ->
        payload_value(payload, ["decision"]) ||
          payload_value(payload, ["explanation", "summary"]) ||
          "Policy evaluated"

      "ExceptionRequested" ->
        payload_value(payload, ["exception_id"]) || "Exception requested"

      "ApprovalRecorded" ->
        payload_value(payload, ["decision"]) ||
          payload_value(payload, ["status"]) ||
          "Approval recorded"

      "ActionProposed" ->
        payload_value(payload, ["action_id"]) || "Action proposed"

      "ActionCommitted" ->
        payload_value(payload, ["action_id"]) || "Action committed"

      "TraceFinished" ->
        payload_value(payload, ["outcome"]) || "Trace finished"

      _other ->
        "Event recorded"
    end
  end

  defp operator_actor_result do
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

  defp operator_request_id(prefix) do
    "#{prefix}-console-#{System.unique_integer([:positive])}"
  end

  defp maybe_add_alert(alerts, false, _kind, _title, _detail), do: alerts

  defp maybe_add_alert(alerts, true, kind, title, detail) do
    alerts ++ [%{"detail" => detail, "kind" => kind, "title" => title}]
  end

  defp first_recent_trace_id(%{items: [%{"trace_id" => trace_id} | _rest]}), do: trace_id
  defp first_recent_trace_id(_section), do: nil

  defp first_workflow_id(%{data: %{"items" => items}}, trace_id) when is_list(items) do
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

  defp first_workflow_id(_section, _trace_id), do: nil

  defp normalize_recent_limit(limit) when is_integer(limit) and limit > 0 do
    min(limit, 24)
  end

  defp normalize_recent_limit(limit) do
    limit
    |> to_string()
    |> Integer.parse()
    |> case do
      {value, ""} when value > 0 -> min(value, 24)
      _other -> @default_recent_limit
    end
  end

  defp normalize_event_limit(limit) when is_integer(limit) and limit > 0 do
    min(limit, 24)
  end

  defp normalize_event_limit(limit) do
    limit
    |> to_string()
    |> Integer.parse()
    |> case do
      {value, ""} when value > 0 -> min(value, 24)
      _other -> @default_event_limit
    end
  end

  defp normalize_run_limit(limit) when is_integer(limit) and limit > 0 do
    min(limit, 12)
  end

  defp normalize_run_limit(limit) do
    limit
    |> to_string()
    |> Integer.parse()
    |> case do
      {value, ""} when value > 0 -> min(value, 12)
      _other -> @default_run_limit
    end
  end

  defp normalize_failure_limit(limit) when is_integer(limit) and limit > 0 do
    min(limit, 10)
  end

  defp normalize_failure_limit(limit) do
    limit
    |> to_string()
    |> Integer.parse()
    |> case do
      {value, ""} when value > 0 -> min(value, 10)
      _other -> @default_failure_limit
    end
  end

  defp normalize_tenant_id(value) do
    value
    |> normalize_optional_string()
    |> case do
      nil -> "default"
      tenant_id -> tenant_id
    end
  end

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

  defp field_integer(map, key) do
    case Map.get(map, key) do
      value when is_integer(value) -> value
      _other -> 0
    end
  end

  defp truthy_field?(map, key), do: Map.get(map, key) in [true, "true"]

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

    next_value =
      cond do
        Map.has_key?(map, key) -> Map.get(map, key)
        atom_key && Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
        true -> nil
      end

    payload_value(next_value, rest)
  end

  defp payload_value(_value, _path), do: nil

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: false

  defp entity_label(summary) do
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

  defp serialize_data(value) do
    value
    |> Serialization.serialize()
    |> stringify_keys()
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
