defmodule DecisionGraph.Projector.Digests do
  @moduledoc false

  alias DecisionGraph.Domain.CanonicalJson
  alias DecisionGraph.Projector.SQL

  @projection_names [:context_graph, :trace_summary, :precedent_index]

  @spec compute_projection_digest(atom(), String.t()) :: String.t()
  def compute_projection_digest(:context_graph, tenant_id),
    do: compute_context_graph_digest(tenant_id)

  def compute_projection_digest(:trace_summary, tenant_id),
    do: compute_trace_summary_digest(tenant_id)

  def compute_projection_digest(:precedent_index, tenant_id),
    do: compute_precedent_index_digest(tenant_id)

  @spec compute_all(String.t()) :: map()
  def compute_all(tenant_id) do
    graph_digest = compute_context_graph_digest(tenant_id)
    trace_summary_digest = compute_trace_summary_digest(tenant_id)
    precedent_digest = compute_precedent_index_digest(tenant_id)

    %{
      context_graph: graph_digest,
      trace_summary: trace_summary_digest,
      precedent_index: precedent_digest,
      full_projection: hash("#{graph_digest}:#{trace_summary_digest}:#{precedent_digest}")
    }
  end

  @spec projection_names() :: [atom()]
  def projection_names, do: @projection_names

  @spec compute_context_graph_digest(String.t()) :: String.t()
  def compute_context_graph_digest(tenant_id) do
    nodes =
      SQL.query_all!(
        """
        SELECT node_id, node_type, trace_id, log_seq, created_at, metadata_json
        FROM dg_cg_nodes
        WHERE tenant_id = $1
        ORDER BY node_id
        """,
        [tenant_id]
      )
      |> Enum.map(fn row ->
        %{
          "node_id" => row["node_id"],
          "node_type" => row["node_type"],
          "trace_id" => row["trace_id"],
          "log_seq" => row["log_seq"],
          "created_at" => row["created_at"],
          "attrs" => decode_json(row["metadata_json"])
        }
      end)

    edges =
      SQL.query_all!(
        """
        SELECT edge_id, edge_type, from_node_id, to_node_id, trace_id, log_seq, created_at, metadata_json
        FROM dg_cg_edges
        WHERE tenant_id = $1
        ORDER BY edge_id
        """,
        [tenant_id]
      )
      |> Enum.map(fn row ->
        %{
          "edge_id" => row["edge_id"],
          "edge_type" => row["edge_type"],
          "from_node_id" => row["from_node_id"],
          "to_node_id" => row["to_node_id"],
          "trace_id" => row["trace_id"],
          "log_seq" => row["log_seq"],
          "created_at" => row["created_at"],
          "attrs" => decode_json(row["metadata_json"])
        }
      end)

    %{"nodes" => nodes, "edges" => edges}
    |> CanonicalJson.canonicalize!()
    |> hash()
  end

  @spec compute_trace_summary_digest(String.t()) :: String.t()
  def compute_trace_summary_digest(tenant_id) do
    SQL.query_all!(
      """
      SELECT trace_id, workflow, title, primary_entity_type, primary_entity_id,
             outcome, started_at, finished_at, event_count, last_log_seq
      FROM dg_trace_summary
      WHERE tenant_id = $1
      ORDER BY trace_id
      """,
      [tenant_id]
    )
    |> Enum.map(fn row ->
      %{
        "trace_id" => row["trace_id"],
        "workflow" => row["workflow"],
        "title" => row["title"],
        "primary_entity_type" => row["primary_entity_type"],
        "primary_entity_id" => row["primary_entity_id"],
        "outcome" => row["outcome"],
        "started_at" => row["started_at"],
        "finished_at" => row["finished_at"],
        "event_count" => row["event_count"],
        "last_log_seq" => row["last_log_seq"]
      }
    end)
    |> CanonicalJson.canonicalize!()
    |> hash()
  end

  @spec compute_precedent_index_digest(String.t()) :: String.t()
  def compute_precedent_index_digest(tenant_id) do
    SQL.query_all!(
      """
      SELECT source_event_id, log_seq, trace_id, policy_id, policy_version,
             exception_id, primary_entity_type, primary_entity_system, primary_entity_id
      FROM dg_precedent_index
      WHERE tenant_id = $1
      ORDER BY source_event_id
      """,
      [tenant_id]
    )
    |> Enum.map(fn row ->
      %{
        "source_event_id" => row["source_event_id"],
        "log_seq" => row["log_seq"],
        "trace_id" => row["trace_id"],
        "policy_id" => row["policy_id"],
        "policy_version" => row["policy_version"],
        "exception_id" => row["exception_id"],
        "primary_entity_type" => row["primary_entity_type"],
        "primary_entity_system" => row["primary_entity_system"],
        "primary_entity_id" => row["primary_entity_id"]
      }
    end)
    |> CanonicalJson.canonicalize!()
    |> hash()
  end

  defp decode_json(nil), do: %{}
  defp decode_json(value) when value in ["", "null"], do: %{}
  defp decode_json(value), do: Jason.decode!(value)

  defp hash(value) do
    "sha256:" <> Base.encode16(:crypto.hash(:sha256, value), case: :lower)
  end
end
