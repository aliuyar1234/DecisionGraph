defmodule DecisionGraph.Projector.Engine do
  @moduledoc false

  alias DecisionGraph.Projector.Admin
  alias DecisionGraph.Projector.Query
  alias DecisionGraph.Projector.Write

  defdelegate catch_up(projection_name, opts \\ []), to: Write
  defdelegate rebuild(projection_name, opts \\ []), to: Write
  defdelegate rebuild_all(opts \\ []), to: Write
  defdelegate failure_recoverable?(error), to: Write
  defdelegate record_failure!(projection_name, tenant_id, event, error, opts \\ []), to: Write

  defdelegate get_trace_summary(trace_id, opts \\ []), to: Query
  defdelegate get_context_subgraph(center, opts \\ []), to: Query
  defdelegate list_node_edges(node, opts \\ []), to: Query
  defdelegate find_precedents(query, opts \\ []), to: Query

  defdelegate projection_health(opts \\ []), to: Admin
  defdelegate list_runs(opts \\ []), to: Admin
  defdelegate get_run(job_id), to: Admin
  defdelegate create_run!(job_id, projection_name, mode, opts), to: Admin
  defdelegate mark_run_running!(job_id), to: Admin
  defdelegate mark_run_progress!(job_id, processed_events, last_log_seq), to: Admin
  defdelegate mark_run_completed!(job_id, processed_events, last_log_seq), to: Admin
  defdelegate mark_run_failed!(job_id, error, processed_events, last_log_seq), to: Admin
  defdelegate mark_run_cancelled!(job_id, processed_events, last_log_seq), to: Admin
  defdelegate list_failures(opts \\ []), to: Admin
end
