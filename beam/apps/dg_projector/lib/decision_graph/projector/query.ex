defmodule DecisionGraph.Projector.Query do
  @moduledoc false

  alias DecisionGraph.Error

  alias DecisionGraph.Projector.{
    ContextSubgraph,
    Edge,
    GraphEdgeCursor,
    GraphEdgePage,
    GraphFilter,
    Node,
    NodeRef,
    PrecedentHit,
    PrecedentQuery,
    TraceSummary
  }

  alias DecisionGraph.Projector.SQL
  alias DecisionGraph.Projector.Support
  alias DecisionGraph.Store

  @max_graph_depth 10

  @spec get_trace_summary(String.t(), keyword()) :: TraceSummary.t()
  def get_trace_summary(trace_id, opts \\ []) do
    tenant_id = Support.normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))
    ensure_projection_current!(tenant_id, :trace_summary)

    row =
      SQL.query_all!(
        """
        SELECT trace_id, workflow, title, primary_entity_type, primary_entity_system, primary_entity_id,
               started_at, finished_at, outcome, event_count, last_log_seq
        FROM dg_trace_summary
        WHERE tenant_id = $1 AND trace_id = $2
        LIMIT 1
        """,
        [tenant_id, trace_id]
      )
      |> List.first()

    if is_nil(row) do
      raise Error, code: :not_found, message: "Trace not found: #{trace_id}"
    end

    %TraceSummary{
      trace_id: row["trace_id"],
      workflow: row["workflow"],
      title: row["title"],
      primary_entity_type: row["primary_entity_type"],
      primary_entity_system: row["primary_entity_system"],
      primary_entity_id: row["primary_entity_id"],
      started_at: row["started_at"],
      finished_at: row["finished_at"],
      outcome: row["outcome"],
      event_count: row["event_count"],
      last_log_seq: row["last_log_seq"]
    }
  end

  @spec get_context_subgraph(NodeRef.t() | map(), keyword()) :: ContextSubgraph.t()
  def get_context_subgraph(center, opts \\ []) do
    center = normalize_node_ref(center)
    tenant_id = Support.normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))
    ensure_projection_current!(tenant_id, :context_graph)

    filter = normalize_graph_filter(Keyword.get(opts, :filter, %GraphFilter{}))
    center_key = NodeRef.key(center)

    {visited_nodes, visited_edges, truncated} =
      traverse_context_graph(
        tenant_id,
        filter,
        MapSet.new([center_key]),
        MapSet.new([center_key]),
        MapSet.new(),
        false,
        0
      )

    %ContextSubgraph{
      center: center,
      nodes: fetch_graph_nodes(tenant_id, MapSet.to_list(visited_nodes)),
      edges: fetch_graph_edges(tenant_id, MapSet.to_list(visited_edges)),
      truncated: truncated
    }
  end

  @spec list_node_edges(NodeRef.t() | map(), keyword()) :: GraphEdgePage.t()
  def list_node_edges(node, opts \\ []) do
    node = normalize_node_ref(node)
    tenant_id = Support.normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))
    ensure_projection_current!(tenant_id, :context_graph)

    direction = normalize_direction(Keyword.get(opts, :direction, :both))
    cursor = Keyword.get(opts, :cursor)
    limit = Support.normalize_limit(Keyword.get(opts, :limit, 100))

    if match?(%GraphEdgeCursor{}, cursor) and cursor.direction != direction do
      raise Error, code: :invalid_argument, message: "cursor.direction must match direction"
    end

    node_key = NodeRef.key(node)
    {where_sql, params} = edge_query_scope(direction, node_key, tenant_id)
    {cursor_sql, cursor_params} = edge_cursor_clause(tenant_id, cursor)

    rows =
      SQL.query_all!(
        """
        SELECT edge_id, edge_type, from_node_id, to_node_id, trace_id, log_seq, created_at, metadata_json
        FROM dg_cg_edges
        WHERE #{where_sql}#{cursor_sql}
        ORDER BY log_seq ASC, edge_id ASC
        LIMIT $#{length(params) + length(cursor_params) + 1}
        """,
        params ++ cursor_params ++ [limit + 1]
      )

    edges = rows |> Enum.take(limit) |> Enum.map(&row_to_edge/1)

    next_cursor =
      if length(rows) > limit and edges != [] do
        last_edge = List.last(edges)

        %GraphEdgeCursor{
          edge_key: last_edge.edge_id,
          direction: direction,
          log_seq: last_edge.log_seq
        }
      end

    %GraphEdgePage{edges: edges, next_cursor: next_cursor}
  end

  @spec find_precedents(PrecedentQuery.t() | map() | keyword(), keyword()) :: [PrecedentHit.t()]
  def find_precedents(query, opts \\ []) do
    tenant_id = Support.normalize_tenant_id(Keyword.get(opts, :tenant_id, "default"))
    ensure_projection_current!(tenant_id, :precedent_index)
    query = PrecedentQuery.new(query)

    {conditions, params} =
      {["ts.tenant_id = $1", "ts.outcome IS NOT NULL"], [tenant_id]}
      |> add_condition(query.outcome, "ts.outcome = $%d")
      |> add_condition(query.entity_type, "ts.primary_entity_type = $%d")
      |> add_condition(query.entity_id, "ts.primary_entity_id = $%d")

    rows =
      if query.policy_id do
        {policy_conditions, policy_params} =
          {conditions, params}
          |> add_condition(query.policy_id, "pi.policy_id = $%d")
          |> add_condition(query.policy_version, "pi.policy_version = $%d")

        SQL.query_all!(
          """
          SELECT trace_id, workflow, title, outcome, finished_at, policy_id, policy_version
          FROM (
            SELECT
              ts.trace_id,
              ts.workflow,
              ts.title,
              ts.outcome,
              ts.finished_at,
              ts.last_log_seq,
              pi.policy_id,
              pi.policy_version,
              ROW_NUMBER() OVER (
                PARTITION BY ts.trace_id
                ORDER BY
                  CASE WHEN pi.exception_id IS NOT NULL THEN 0 ELSE 1 END,
                  pi.log_seq DESC,
                  pi.source_event_id ASC
              ) AS row_rank
            FROM dg_trace_summary ts
            JOIN dg_precedent_index pi
              ON pi.tenant_id = ts.tenant_id AND pi.trace_id = ts.trace_id
            WHERE #{Enum.join(policy_conditions, " AND ")}
          ) ranked
          WHERE row_rank = 1
          ORDER BY last_log_seq DESC, trace_id ASC
          LIMIT $#{length(policy_params) + 1}
          """,
          policy_params ++ [query.limit]
        )
      else
        SQL.query_all!(
          """
          SELECT trace_id, workflow, title, outcome, finished_at
          FROM dg_trace_summary ts
          WHERE #{Enum.join(conditions, " AND ")}
          ORDER BY last_log_seq DESC, trace_id ASC
          LIMIT $#{length(params) + 1}
          """,
          params ++ [query.limit]
        )
      end

    Enum.map(rows, fn row ->
      %PrecedentHit{
        trace_id: row["trace_id"],
        workflow: row["workflow"],
        title: row["title"],
        outcome: row["outcome"],
        policy_id: row["policy_id"],
        policy_version: row["policy_version"],
        finished_at: row["finished_at"]
      }
    end)
  end

  defp ensure_projection_current!(tenant_id, projection_name) do
    projection_cursor = Store.get_projection_cursor(projection_name, tenant_id: tenant_id)
    event_cursor = Store.get_last_log_seq(tenant_id: tenant_id)

    if projection_cursor < event_cursor do
      raise Error,
        code: :projection_out_of_date,
        message: "Projections at log_seq=#{projection_cursor}, events at #{event_cursor}"
    end
  end

  defp normalize_graph_filter(%GraphFilter{} = filter), do: validate_graph_filter!(filter)

  defp normalize_graph_filter(filter) when is_map(filter) or is_list(filter) do
    attrs = Map.new(filter)

    %GraphFilter{
      edge_types: Map.get(attrs, :edge_types, Map.get(attrs, "edge_types")),
      max_depth: Map.get(attrs, :max_depth, Map.get(attrs, "max_depth", 1)),
      max_edges: Map.get(attrs, :max_edges, Map.get(attrs, "max_edges", 100)),
      max_nodes: Map.get(attrs, :max_nodes, Map.get(attrs, "max_nodes", 100)),
      node_types: Map.get(attrs, :node_types, Map.get(attrs, "node_types"))
    }
    |> validate_graph_filter!()
  end

  defp validate_graph_filter!(%GraphFilter{} = filter) do
    if filter.max_depth < 0 or filter.max_depth > @max_graph_depth do
      raise Error,
        code: :invalid_argument,
        message: "max_depth must be between 0 and #{@max_graph_depth}"
    end

    if filter.max_nodes <= 0 or filter.max_edges <= 0 do
      raise Error, code: :invalid_argument, message: "max_nodes and max_edges must be positive"
    end

    if filter.node_types && not is_list(filter.node_types) do
      raise Error, code: :invalid_argument, message: "node_types must be a list when provided"
    end

    if filter.edge_types && not is_list(filter.edge_types) do
      raise Error, code: :invalid_argument, message: "edge_types must be a list when provided"
    end

    filter
  end

  defp traverse_context_graph(
         tenant_id,
         %GraphFilter{} = filter,
         frontier,
         visited_nodes,
         visited_edges,
         truncated,
         depth
       ) do
    if truncated or MapSet.size(frontier) == 0 or depth >= filter.max_depth do
      {visited_nodes, visited_edges, truncated}
    else
      {edge_type_clause, edge_type_params} =
        if is_list(filter.edge_types) and filter.edge_types != [] do
          {" AND edge_type = ANY($3::text[])", [filter.edge_types]}
        else
          {"", []}
        end

      rows =
        SQL.query_all!(
          """
          SELECT edge_id, edge_type, from_node_id, to_node_id, trace_id, log_seq, created_at, metadata_json
          FROM dg_cg_edges
          WHERE tenant_id = $1
            AND (from_node_id = ANY($2::text[]) OR to_node_id = ANY($2::text[]))#{edge_type_clause}
          ORDER BY edge_id
          """,
          [tenant_id, MapSet.to_list(frontier)] ++ edge_type_params
        )

      {next_frontier, next_nodes, next_edges, next_truncated} =
        Enum.reduce_while(rows, {MapSet.new(), visited_nodes, visited_edges, false}, fn row,
                                                                                        {frontier_acc,
                                                                                         nodes_acc,
                                                                                         edges_acc,
                                                                                         truncated_acc} ->
          if truncated_acc do
            {:halt, {frontier_acc, nodes_acc, edges_acc, true}}
          else
            edge_id = row["edge_id"]

            cond do
              MapSet.member?(edges_acc, edge_id) ->
                {:cont, {frontier_acc, nodes_acc, edges_acc, false}}

              MapSet.size(edges_acc) >= filter.max_edges ->
                {:halt, {frontier_acc, nodes_acc, edges_acc, true}}

              true ->
                next_edges_acc = MapSet.put(edges_acc, edge_id)

                {next_frontier_acc, next_nodes_acc, node_truncated} =
                  Enum.reduce_while(
                    [row["from_node_id"], row["to_node_id"]],
                    {frontier_acc, nodes_acc, false},
                    fn neighbor, {node_frontier_acc, node_set_acc, node_truncated_acc} ->
                      cond do
                        node_truncated_acc ->
                          {:halt, {node_frontier_acc, node_set_acc, true}}

                        MapSet.member?(node_set_acc, neighbor) ->
                          {:cont, {node_frontier_acc, node_set_acc, false}}

                        not allowed_node_type?(neighbor, filter.node_types) ->
                          {:cont, {node_frontier_acc, node_set_acc, false}}

                        MapSet.size(node_set_acc) >= filter.max_nodes ->
                          {:halt, {node_frontier_acc, node_set_acc, true}}

                        true ->
                          {:cont,
                           {MapSet.put(node_frontier_acc, neighbor),
                            MapSet.put(node_set_acc, neighbor), false}}
                      end
                    end
                  )

                {:cont, {next_frontier_acc, next_nodes_acc, next_edges_acc, node_truncated}}
            end
          end
        end)

      traverse_context_graph(
        tenant_id,
        filter,
        next_frontier,
        next_nodes,
        next_edges,
        next_truncated,
        depth + 1
      )
    end
  end

  defp fetch_graph_nodes(_tenant_id, []), do: []

  defp fetch_graph_nodes(tenant_id, node_ids) do
    SQL.query_all!(
      """
      SELECT node_id, node_type, trace_id, log_seq, created_at, metadata_json
      FROM dg_cg_nodes
      WHERE tenant_id = $1 AND node_id = ANY($2::text[])
      ORDER BY node_id
      """,
      [tenant_id, node_ids]
    )
    |> Enum.map(&row_to_node/1)
  end

  defp fetch_graph_edges(_tenant_id, []), do: []

  defp fetch_graph_edges(tenant_id, edge_ids) do
    SQL.query_all!(
      """
      SELECT edge_id, edge_type, from_node_id, to_node_id, trace_id, log_seq, created_at, metadata_json
      FROM dg_cg_edges
      WHERE tenant_id = $1 AND edge_id = ANY($2::text[])
      ORDER BY edge_id
      """,
      [tenant_id, edge_ids]
    )
    |> Enum.map(&row_to_edge/1)
  end

  defp row_to_node(row) do
    %Node{
      node_id: row["node_id"],
      node_type: row["node_type"],
      trace_id: row["trace_id"],
      log_seq: row["log_seq"],
      created_at: row["created_at"],
      attrs: Support.decode_json_map(row["metadata_json"])
    }
  end

  defp row_to_edge(row) do
    %Edge{
      edge_id: row["edge_id"],
      edge_type: row["edge_type"],
      from_node_id: row["from_node_id"],
      to_node_id: row["to_node_id"],
      trace_id: row["trace_id"],
      log_seq: row["log_seq"],
      created_at: row["created_at"],
      attrs: Support.decode_json_map(row["metadata_json"])
    }
  end

  defp edge_query_scope(:outgoing, node_key, tenant_id),
    do: {"tenant_id = $1 AND from_node_id = $2", [tenant_id, node_key]}

  defp edge_query_scope(:incoming, node_key, tenant_id),
    do: {"tenant_id = $1 AND to_node_id = $2", [tenant_id, node_key]}

  defp edge_query_scope(:both, node_key, tenant_id) do
    {"tenant_id = $1 AND (from_node_id = $2 OR to_node_id = $2)", [tenant_id, node_key]}
  end

  defp edge_cursor_clause(_tenant_id, nil), do: {"", []}

  defp edge_cursor_clause(tenant_id, %GraphEdgeCursor{} = cursor) do
    cursor_log_seq =
      cursor.log_seq ||
        SQL.query_all!(
          """
          SELECT log_seq
          FROM dg_cg_edges
          WHERE tenant_id = $1 AND edge_id = $2
          LIMIT 1
          """,
          [tenant_id, cursor.edge_key]
        )
        |> List.first()
        |> case do
          nil ->
            raise Error,
              code: :invalid_argument,
              message: "cursor.edge_key not found: #{cursor.edge_key}"

          row ->
            row["log_seq"]
        end

    {" AND (log_seq > $3 OR (log_seq = $3 AND edge_id > $4))", [cursor_log_seq, cursor.edge_key]}
  end

  defp normalize_direction(direction) when direction in [:incoming, :outgoing, :both],
    do: direction

  defp normalize_direction(direction) do
    raise Error, code: :invalid_argument, message: "Unknown direction #{inspect(direction)}"
  end

  defp add_condition({conditions, params}, nil, _template), do: {conditions, params}

  defp add_condition({conditions, params}, value, template) do
    placeholder = Integer.to_string(length(params) + 1)
    {conditions ++ [String.replace(template, "%d", placeholder)], params ++ [value]}
  end

  defp allowed_node_type?(_neighbor, nil), do: true
  defp allowed_node_type?(_neighbor, []), do: true

  defp allowed_node_type?(neighbor, node_types) do
    node_type = neighbor |> String.split(":", parts: 2) |> hd()
    node_type in node_types
  end

  defp normalize_node_ref(%NodeRef{} = node_ref), do: node_ref

  defp normalize_node_ref(node_ref) when is_map(node_ref) or is_list(node_ref) do
    attrs = Map.new(node_ref)
    node_type = Map.get(attrs, :node_type, Map.get(attrs, "node_type"))
    node_id = Map.get(attrs, :node_id, Map.get(attrs, "node_id"))

    if Support.blank?(node_type) or Support.blank?(node_id) do
      raise Error, code: :invalid_argument, message: "node_type and node_id are required"
    end

    %NodeRef{node_type: to_string(node_type), node_id: to_string(node_id)}
  end
end
