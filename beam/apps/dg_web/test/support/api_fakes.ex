defmodule DecisionGraphWeb.Test.EventServiceFake do
  def append_event(params, opts) do
    {:ok,
     %{
       event: %{
         event_id: Map.get(params, "event_id"),
         event_type: Map.get(params, "event_type"),
         tenant_id: Keyword.fetch!(opts, :tenant_id),
         trace_id: Map.get(params, "trace_id")
       },
       projection_sync_triggered: true
     }}
  end
end

defmodule DecisionGraphWeb.Test.TraceServiceFake do
  def get_trace(trace_id, opts) do
    {:ok,
     %{
       events: [
         %{
           actor: %{actor_id: "agent-7", actor_type: "agent"},
           event_id: "evt-1",
           event_type: "TraceStarted",
           occurred_at: "2026-03-07T10:00:00Z",
           payload: %{
             "primary_entity" => %{"entity_id" => "deal-42", "entity_type" => "deal"},
             "title" => "Escalated deal review",
             "workflow" => "fake_workflow"
           },
           trace_id: trace_id,
           trace_seq: 0
         },
         %{
           actor: %{actor_id: "policy-engine", actor_type: "service"},
           event_id: "evt-2",
           event_type: "PolicyEvaluated",
           occurred_at: "2026-03-07T10:01:00Z",
           payload: %{
             "decision" => "allow",
             "explanation" => %{"summary" => "Within policy tolerance"},
             "policy" => %{"policy_id" => "discount-cap", "policy_version" => "2026.03"}
           },
           trace_id: trace_id,
           trace_seq: 1
         },
         %{
           actor: %{actor_id: "policy-engine", actor_type: "service"},
           event_id: "evt-3",
           event_type: "ExceptionRequested",
           occurred_at: "2026-03-07T10:02:00Z",
           payload: %{"exception_id" => "ex-42", "reason" => "Strategic renewal over threshold"},
           trace_id: trace_id,
           trace_seq: 2
         },
         %{
           actor: %{actor_id: "fin-12", actor_type: "person"},
           event_id: "evt-4",
           event_type: "ApprovalRecorded",
           occurred_at: "2026-03-07T10:03:00Z",
           payload: %{
             "approver" => %{"actor_id" => "fin-12", "actor_type" => "person"},
             "decision" => "approved",
             "rationale" => "CRO approved strategic exception",
             "subject" => %{"subject_id" => "ex-42", "subject_type" => "exception"}
           },
           trace_id: trace_id,
           trace_seq: 3
         },
         %{
           actor: %{actor_id: "agent-7", actor_type: "agent"},
           event_id: "evt-5",
           event_type: "ActionProposed",
           occurred_at: "2026-03-07T10:04:00Z",
           payload: %{
             "action_id" => "apply-discount",
             "target_entity" => %{"entity_id" => "deal-42", "entity_type" => "deal"}
           },
           trace_id: trace_id,
           trace_seq: 4
         },
         %{
           actor: %{actor_id: "agent-7", actor_type: "agent"},
           event_id: "evt-6",
           event_type: "ActionCommitted",
           occurred_at: "2026-03-07T10:05:00Z",
           payload: %{"action_id" => "apply-discount"},
           trace_id: trace_id,
           trace_seq: 5
         }
       ],
       summary: %{
         event_count: 6,
         finished_at: "2026-03-07T10:06:00Z",
         outcome: "success",
         primary_entity_id: "deal-42",
         primary_entity_system: "crm",
         primary_entity_type: "deal",
         started_at: "2026-03-07T10:00:00Z",
         trace_id: trace_id,
         workflow: "fake_workflow",
         tenant_id: Keyword.fetch!(opts, :tenant_id)
       }
     }}
  end

  def list_recent_traces(_limit, _opts) do
    {:ok,
     [
       %{
         event_count: 6,
         last_log_seq: 14,
         status: "success",
         title: "Escalated deal review",
         trace_id: "trace-123",
         workflow: "fake_workflow"
       },
       %{
         event_count: 4,
         last_log_seq: 11,
         status: "running",
         title: "New policy exception",
         trace_id: "trace-456",
         workflow: "policy_review"
       }
     ]}
  end

  def list_recent_events(_limit, _opts) do
    {:ok,
     [
       %{
         actor: %{actor_id: "agent-7", actor_type: "agent"},
         event_id: "evt-6",
         event_type: "ActionCommitted",
         log_seq: 14,
         occurred_at: "2026-03-07T10:05:00Z",
         payload: %{"action_id" => "apply-discount"},
         trace_id: "trace-123"
       },
       %{
         actor: %{actor_id: "fin-12", actor_type: "person"},
         event_id: "evt-4",
         event_type: "ApprovalRecorded",
         log_seq: 13,
         occurred_at: "2026-03-07T10:03:00Z",
         payload: %{"decision" => "approved"},
         trace_id: "trace-123"
       }
     ]}
  end

  def tenant_overview(opts) do
    {:ok,
     %{
       active_trace_count: 1,
       completed_trace_count: 4,
       event_count: 18,
       last_event_at: "2026-03-07T10:05:00Z",
       tenant_id: Keyword.fetch!(opts, :tenant_id),
       trace_count: 5,
       workflows: [
         %{trace_count: 3, workflow: "fake_workflow"},
         %{trace_count: 2, workflow: "policy_review"}
       ]
     }}
  end
end

defmodule DecisionGraphWeb.Test.GraphServiceFake do
  def get_context_subgraph(params, _opts) do
    center_trace_id = params["node_id"]

    {:ok,
     %{
       center: %{node_id: center_trace_id, node_type: params["node_type"]},
       edges: [
         %{
           edge_id: "edge-1",
           edge_type: "trace_evaluated_policy",
           from_node_id: "trace:#{center_trace_id}",
           to_node_id: "policy:discount-cap:2026.03"
         },
         %{
           edge_id: "edge-2",
           edge_type: "trace_requested_exception",
           from_node_id: "trace:#{center_trace_id}",
           to_node_id: "exception:ex-42"
         }
       ],
       nodes: [
         %{node_id: "trace:#{center_trace_id}", node_type: "trace"},
         %{node_id: "policy:discount-cap:2026.03", node_type: "policy"},
         %{node_id: "exception:ex-42", node_type: "exception"}
       ],
       truncated: false
     }}
  end

  def list_node_edges(_params, _opts) do
    {:ok, %{edges: [%{edge_id: "edge-1"}], next_cursor: nil}}
  end
end

defmodule DecisionGraphWeb.Test.PrecedentServiceFake do
  def find_precedents(_params, _opts) do
    {:ok,
     [
       %{
         finished_at: "2026-02-20T09:00:00Z",
         outcome: "success",
         policy_id: "discount-cap",
         policy_version: "2026.03",
         trace_id: "precedent-trace-1",
         title: "Approved enterprise renewal",
         workflow: "fake_workflow"
       },
       %{
         finished_at: "2026-01-13T12:30:00Z",
         outcome: "rejected",
         policy_id: "discount-cap",
         policy_version: "2025.12",
         trace_id: "precedent-trace-2",
         title: "Rejected strategic discount",
         workflow: "policy_review"
       }
     ]}
  end
end

defmodule DecisionGraphWeb.Test.AdminServiceFake do
  def projection_health(opts) do
    {:ok,
     %{
       event_log_last_seq: 14,
       full_digest: "sha256:phase6-full",
       open_runs: [
         %{
           job_id: "job-1",
           mode: "catch_up",
           processed_events: 3,
           projection_name: :trace_summary,
           requested_at: "2026-03-07T10:03:00Z",
           status: "running"
         }
       ],
       projections: [
         %{
           digest: "sha256:trace",
           last_log_seq: 14,
           pending_events: 0,
           projection_name: :trace_summary,
           open_failures: 0
         },
         %{
           digest: "sha256:graph",
           is_stale: true,
           last_log_seq: 12,
           pending_events: 2,
           projection_name: :context_graph,
           open_failures: 0
         },
         %{
           digest: "sha256:precedent",
           last_log_seq: 14,
           pending_events: 0,
           projection_name: :precedent_index,
           open_failures: 1
         }
       ],
       tenant_id: Keyword.fetch!(opts, :tenant_id)
     }}
  end

  def list_runs(_opts) do
    {:ok,
     [
       %{
         finished_at: "2026-03-07T10:07:00Z",
         job_id: "job-2",
         last_log_seq: 14,
         mode: "catch_up",
         processed_events: 14,
         projection_name: "trace_summary",
         status: "completed"
       },
       %{
         finished_at: nil,
         job_id: "job-1",
         last_log_seq: 12,
         mode: "catch_up",
         processed_events: 3,
         projection_name: "context_graph",
         status: "running"
       }
     ]}
  end

  def list_failures(_opts) do
    {:ok,
     [
       %{
         error_message: "Projection worker hit malformed metadata",
         log_seq: 11,
         projection_name: "precedent_index",
         trace_id: "trace-789"
       }
     ]}
  end

  def start_replay(params, opts) do
    {:ok,
     %{
       job_id: "job-1",
       mode: Map.get(params, "mode", "catch_up"),
       projection_name: Map.get(params, "projection"),
       reason: Map.get(params, "reason"),
       status: "queued",
       tenant_id: Keyword.fetch!(opts, :tenant_id)
     }}
  end

  def replay_status(job_id, _opts) do
    {:ok, %{job_id: job_id, status: "completed"}}
  end

  def cancel_replay(job_id, _opts) do
    {:ok, %{job_id: job_id, status: "cancelled"}}
  end
end

defmodule DecisionGraphWeb.Test.WorkflowServiceFake do
  def list_inbox(_params, opts) do
    {:ok,
     %{
       items: [
         %{
           assigned_account_id: "ops-7",
           assigned_role: "admin",
           current_decision: nil,
           current_reason: "Need operator review for exception ex-42",
           overdue: true,
           priority: "urgent",
           requested_at: "2026-03-07T10:02:00Z",
           sla_due_at: "2026-03-07T10:10:00Z",
           status: "requested",
           subject: %{subject_id: "ex-42", subject_type: "exception"},
           tenant_id: Keyword.fetch!(opts, :tenant_id),
           title: "Escalated deal review",
           trace_id: "trace-123",
           workflow_id: "trace-123:exception:ex-42",
           workflow_kind: "exception_review",
           workflow_name: "fake_workflow"
         },
         %{
           assigned_account_id: nil,
           assigned_role: "writer",
           current_decision: nil,
           current_reason: "Policy simulation exceeded tolerance",
           overdue: false,
           priority: "high",
           requested_at: "2026-03-07T11:00:00Z",
           sla_due_at: "2026-03-07T15:00:00Z",
           status: "changes_requested",
           subject: %{subject_id: "ex-77", subject_type: "exception"},
           tenant_id: Keyword.fetch!(opts, :tenant_id),
           title: "New policy exception",
           trace_id: "trace-456",
           workflow_id: "trace-456:exception:ex-77",
           workflow_kind: "exception_review",
           workflow_name: "policy_review"
         }
       ],
       summary: %{
         approved_count: 0,
         changes_requested_count: 1,
         escalated_count: 0,
         open_count: 2,
         notification_count: 2,
         overdue_count: 1,
         requested_count: 1,
         tenant_id: Keyword.fetch!(opts, :tenant_id),
         total_count: 2
       }
     }}
  end

  def get_workflow("trace-123:exception:ex-42", opts) do
    {:ok,
     %{
       actions: [
         %{
           action_id: "wfa:event:evt-3",
           action_type: "requested",
           actor: %{account_id: nil, actor_id: "policy-engine", actor_type: "service"},
           created_at: "2026-03-07T10:02:00Z",
           note: "Strategic renewal over threshold",
           resulting_status: "requested",
           source_event_id: "evt-3",
           trace_id: "trace-123",
           workflow_id: "trace-123:exception:ex-42"
         },
         %{
           action_id: "wfa-2",
           action_type: "comment",
           actor: %{account_id: "ops-7", actor_id: "ops-7", actor_type: "role"},
           created_at: "2026-03-07T10:06:00Z",
           note: "Waiting for finance leadership review.",
           resulting_status: "requested",
           source_event_id: nil,
           trace_id: "trace-123",
           workflow_id: "trace-123:exception:ex-42"
         }
       ],
       notifications: [
         %{
           category: "deadline_risk",
           created_at: "2026-03-07T10:09:00Z",
           message: "Workflow trace-123:exception:ex-42 is nearing its SLA deadline",
           notification_id: "wfn-1",
           payload: %{"warning_minutes" => 30},
           status: "delivered",
           workflow_id: "trace-123:exception:ex-42"
         },
         %{
           category: "escalation",
           created_at: "2026-03-07T10:10:00Z",
           message: "Workflow trace-123:exception:ex-42 escalated to admin",
           notification_id: "wfn-2",
           payload: %{"reason" => "SLA deadline passed"},
           status: "delivered",
           workflow_id: "trace-123:exception:ex-42"
         }
       ],
       review_context: %{
         existing_workflows: [
           %{workflow_id: "trace-123:trace_review:incident_triage", status: "requested"}
         ],
         precedent_preview: [%{trace_id: "precedent-trace-1"}],
         recommended_replay: %{mode: "catch_up", projection: "all"},
         simulation: %{
           priority: "urgent",
           risk_signals: ["exception requested", "precedent divergence"]
         },
         templates: [
           %{template_id: "incident_triage"},
           %{template_id: "exception_follow_up"}
         ],
         trace_summary: %{trace_id: "trace-123"}
       },
       trace_reference: %{
         subject_id: "ex-42",
         subject_type: "exception",
         tenant_id: Keyword.fetch!(opts, :tenant_id),
         trace_id: "trace-123",
         workflow_name: "fake_workflow"
       },
       workflow: %{
         assigned_account_id: "ops-7",
         assigned_role: "admin",
         current_decision: nil,
         current_reason: "Strategic renewal over threshold",
         metadata: %{
           exception_reason: "Strategic renewal over threshold",
           policy: %{policy_id: "discount-cap", policy_version: "2026.03"}
         },
         overdue: true,
         policy_id: "discount-cap",
         policy_version: "2026.03",
         priority: "urgent",
         requested_at: "2026-03-07T10:02:00Z",
         requested_by_actor: %{actor_id: "policy-engine", actor_type: "service"},
         sla_due_at: "2026-03-07T10:10:00Z",
         status: "requested",
         subject: %{subject_id: "ex-42", subject_type: "exception"},
         tenant_id: Keyword.fetch!(opts, :tenant_id),
         title: "Escalated deal review",
         trace_id: "trace-123",
         workflow_id: "trace-123:exception:ex-42",
         workflow_kind: "exception_review",
         workflow_name: "fake_workflow"
       }
     }}
  end

  def get_workflow("trace-456:exception:ex-77", opts) do
    {:ok,
     %{
       actions: [],
       notifications: [],
       review_context: %{
         existing_workflows: [],
         precedent_preview: [],
         recommended_replay: %{mode: "catch_up", projection: "trace_summary"},
         simulation: %{priority: "high", risk_signals: ["trace still active"]},
         templates: [%{template_id: "precedent_gap_review"}],
         trace_summary: %{trace_id: "trace-456"}
       },
       trace_reference: %{
         subject_id: "ex-77",
         subject_type: "exception",
         tenant_id: Keyword.fetch!(opts, :tenant_id),
         trace_id: "trace-456",
         workflow_name: "policy_review"
       },
       workflow: %{
         assigned_account_id: nil,
         assigned_role: "writer",
         current_decision: nil,
         current_reason: "Policy simulation exceeded tolerance",
         metadata: %{},
         overdue: false,
         priority: "high",
         requested_at: "2026-03-07T11:00:00Z",
         requested_by_actor: %{actor_id: "policy-engine", actor_type: "service"},
         sla_due_at: "2026-03-07T15:00:00Z",
         status: "changes_requested",
         subject: %{subject_id: "ex-77", subject_type: "exception"},
         tenant_id: Keyword.fetch!(opts, :tenant_id),
         title: "New policy exception",
         trace_id: "trace-456",
         workflow_id: "trace-456:exception:ex-77",
         workflow_kind: "exception_review",
         workflow_name: "policy_review"
       }
     }}
  end

  def act_on_workflow(workflow_id, params, opts) do
    {:ok,
     %{
       action: %{
         outcome: Map.get(params, "action"),
         workflow_id: workflow_id
       },
       workflow: %{
         status:
           case Map.get(params, "action") do
             "approve" -> "approved"
             "escalate" -> "escalated"
             "reject" -> "rejected"
             "override" -> "overridden"
             "request_change" -> "changes_requested"
             _other -> "requested"
           end,
         tenant_id: Keyword.fetch!(opts, :tenant_id),
         workflow_id: workflow_id
       }
     }}
  end

  def export_workflow(workflow_id, opts) do
    {:ok,
     %{
       audit_summary: %{action_count: 2, workflow_kind: "exception_review"},
       exported_at: "2026-03-07T10:12:00Z",
       export_version: 1,
       trace_reference: %{tenant_id: Keyword.fetch!(opts, :tenant_id), trace_id: "trace-123"},
       workflow: %{workflow_id: workflow_id},
       workflow_actions: [%{action_id: "wfa:event:evt-3"}],
       workflow_notifications: [%{notification_id: "wfn-1"}]
     }}
  end
end

defmodule DecisionGraphWeb.Test.WorkflowStudioServiceFake do
  def list_templates(_opts) do
    {:ok,
     [
       %{
         default_priority: "high",
         default_sla_hours: 2,
         reviewer_role: "admin",
         template_id: "incident_triage",
         title: "Incident Triage Review"
       },
       %{
         default_priority: "urgent",
         default_sla_hours: 1,
         reviewer_role: "admin",
         template_id: "exception_follow_up",
         title: "Exception Follow-Up"
       }
     ]}
  end

  def overview(trace_id, _params, _opts) do
    {:ok,
     %{
       draft: %{
         assigned_role: "admin",
         priority: "urgent",
         reason:
           "Incident Triage Review opened for Escalated deal review: exception requested, precedent divergence",
         workflow_id: "#{trace_id}:trace_review:incident_triage"
       },
       existing_workflows: [
         %{
           overdue: false,
           status: "requested",
           title: "Incident review for Escalated deal review",
           trace_id: trace_id,
           workflow_id: "#{trace_id}:trace_review:incident_triage"
         }
       ],
       precedent_preview: [%{trace_id: "precedent-trace-1"}],
       replay_suggestion: %{mode: "catch_up", projection: "all", reason: "workflow studio review"},
       simulation: %{
         priority: "urgent",
         risk_signals: ["exception requested", "precedent divergence"]
       },
       template: %{
         default_sla_hours: 2,
         reviewer_role: "admin",
         template_id: "incident_triage",
         title: "Incident Triage Review"
       },
       templates: [
         %{
           default_sla_hours: 2,
           reviewer_role: "admin",
           template_id: "incident_triage",
           title: "Incident Triage Review"
         },
         %{
           default_sla_hours: 1,
           reviewer_role: "admin",
           template_id: "exception_follow_up",
           title: "Exception Follow-Up"
         }
       ],
       trace_id: trace_id
     }}
  end

  def start_review(trace_id, _params, opts) do
    {:ok,
     %{
       action: %{outcome: "start_review"},
       created: true,
       review_context: %{trace_summary: %{trace_id: trace_id}},
       workflow: %{
         status: "requested",
         tenant_id: Keyword.fetch!(opts, :tenant_id),
         trace_id: trace_id,
         workflow_id: "#{trace_id}:trace_review:incident_triage"
       }
     }}
  end
end
