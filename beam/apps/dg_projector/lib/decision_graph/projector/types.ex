defmodule DecisionGraph.Projector.Node do
  @moduledoc "Context-graph node emitted from the append-only event log."

  @enforce_keys [:node_id, :node_type, :trace_id, :log_seq, :created_at]
  defstruct [:node_id, :node_type, :trace_id, :log_seq, :created_at, attrs: %{}]

  @type t :: %__MODULE__{
          node_id: String.t(),
          node_type: String.t(),
          trace_id: String.t(),
          log_seq: pos_integer(),
          created_at: String.t(),
          attrs: map()
        }
end

defmodule DecisionGraph.Projector.Edge do
  @moduledoc "Context-graph edge emitted from the append-only event log."

  @enforce_keys [
    :edge_id,
    :edge_type,
    :from_node_id,
    :to_node_id,
    :trace_id,
    :log_seq,
    :created_at
  ]
  defstruct [
    :edge_id,
    :edge_type,
    :from_node_id,
    :to_node_id,
    :trace_id,
    :log_seq,
    :created_at,
    attrs: %{}
  ]

  @type t :: %__MODULE__{
          edge_id: String.t(),
          edge_type: String.t(),
          from_node_id: String.t(),
          to_node_id: String.t(),
          trace_id: String.t(),
          log_seq: pos_integer(),
          created_at: String.t(),
          attrs: map()
        }
end

defmodule DecisionGraph.Projector.NodeRef do
  @moduledoc "Reference to a graph node."

  @enforce_keys [:node_type, :node_id]
  defstruct [:node_type, :node_id]

  @type t :: %__MODULE__{
          node_type: String.t(),
          node_id: String.t()
        }

  @spec key(t()) :: String.t()
  def key(%__MODULE__{node_type: node_type, node_id: node_id}), do: "#{node_type}:#{node_id}"
end

defmodule DecisionGraph.Projector.ContextSubgraph do
  @moduledoc "Breadth-first scoped subgraph around a center node."

  @enforce_keys [:center, :nodes, :edges, :truncated]
  defstruct [:center, :nodes, :edges, :truncated]

  @type t :: %__MODULE__{
          center: DecisionGraph.Projector.NodeRef.t(),
          nodes: [DecisionGraph.Projector.Node.t()],
          edges: [DecisionGraph.Projector.Edge.t()],
          truncated: boolean()
        }
end

defmodule DecisionGraph.Projector.GraphFilter do
  @moduledoc "Optional filters and limits for scoped graph traversal."

  defstruct edge_types: nil,
            max_depth: 1,
            max_edges: 100,
            max_nodes: 100,
            node_types: nil

  @type t :: %__MODULE__{
          edge_types: [String.t()] | nil,
          max_depth: pos_integer(),
          max_edges: pos_integer(),
          max_nodes: pos_integer(),
          node_types: [String.t()] | nil
        }
end

defmodule DecisionGraph.Projector.GraphEdgeCursor do
  @moduledoc "Stable cursor for graph-edge pagination."

  @enforce_keys [:edge_key, :direction]
  defstruct [:edge_key, :direction, :log_seq]

  @type t :: %__MODULE__{
          edge_key: String.t(),
          direction: :incoming | :outgoing | :both,
          log_seq: non_neg_integer() | nil
        }
end

defmodule DecisionGraph.Projector.GraphEdgePage do
  @moduledoc "Page of graph edges plus the next cursor when more rows exist."

  @enforce_keys [:edges]
  defstruct [:edges, :next_cursor]

  @type t :: %__MODULE__{
          edges: [DecisionGraph.Projector.Edge.t()],
          next_cursor: DecisionGraph.Projector.GraphEdgeCursor.t() | nil
        }
end

defmodule DecisionGraph.Projector.TraceSummary do
  @moduledoc "Trace-summary projection row exposed through Phase 4 query surfaces."

  @enforce_keys [:trace_id, :workflow, :title, :started_at]
  defstruct [
    :trace_id,
    :workflow,
    :title,
    :primary_entity_type,
    :primary_entity_system,
    :primary_entity_id,
    :started_at,
    :finished_at,
    :outcome,
    :event_count,
    :last_log_seq
  ]

  @type t :: %__MODULE__{
          trace_id: String.t(),
          workflow: String.t(),
          title: String.t(),
          primary_entity_type: String.t() | nil,
          primary_entity_system: String.t() | nil,
          primary_entity_id: String.t() | nil,
          started_at: String.t(),
          finished_at: String.t() | nil,
          outcome: String.t() | nil,
          event_count: non_neg_integer() | nil,
          last_log_seq: non_neg_integer() | nil
        }
end

defmodule DecisionGraph.Projector.PrecedentQuery do
  @moduledoc "Query filter for precedent lookup."

  alias DecisionGraph.Error

  defstruct policy_id: nil,
            policy_version: nil,
            entity_type: nil,
            entity_id: nil,
            outcome: nil,
            limit: 100

  @type t :: %__MODULE__{
          policy_id: String.t() | nil,
          policy_version: String.t() | nil,
          entity_type: String.t() | nil,
          entity_id: String.t() | nil,
          outcome: String.t() | nil,
          limit: pos_integer()
        }

  @spec new(map() | keyword() | t()) :: t()
  def new(%__MODULE__{} = query) do
    validate!(query)
    query
  end

  def new(attrs) do
    attrs = Map.new(attrs)

    query = %__MODULE__{
      policy_id: fetch_optional(attrs, :policy_id),
      policy_version: fetch_optional(attrs, :policy_version),
      entity_type: fetch_optional(attrs, :entity_type),
      entity_id: fetch_optional(attrs, :entity_id),
      outcome: fetch_optional(attrs, :outcome),
      limit: Map.get(attrs, :limit, Map.get(attrs, "limit", 100))
    }

    validate!(query)
    query
  end

  defp fetch_optional(attrs, key), do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))

  defp validate!(%__MODULE__{} = query) do
    if query.policy_version && is_nil(query.policy_id) do
      raise Error, code: :invalid_argument, message: "policy_version requires policy_id"
    end

    if query.entity_id && is_nil(query.entity_type) do
      raise Error, code: :invalid_argument, message: "entity_id requires entity_type"
    end

    if not is_integer(query.limit) or query.limit <= 0 or query.limit > 10_000 do
      raise Error, code: :invalid_argument, message: "limit must be between 1 and 10000"
    end
  end
end

defmodule DecisionGraph.Projector.PrecedentHit do
  @moduledoc "Finished-trace hit returned by precedent lookup."

  @enforce_keys [:trace_id, :workflow, :title, :outcome, :finished_at]
  defstruct [:trace_id, :workflow, :title, :outcome, :policy_id, :policy_version, :finished_at]

  @type t :: %__MODULE__{
          trace_id: String.t(),
          workflow: String.t(),
          title: String.t(),
          outcome: String.t(),
          policy_id: String.t() | nil,
          policy_version: String.t() | nil,
          finished_at: String.t()
        }
end

defmodule DecisionGraph.Projector.ProjectionStatus do
  @moduledoc "Health snapshot for one projection."

  @enforce_keys [:projection_name, :last_log_seq, :pending_events, :is_stale, :open_failures]
  defstruct [
    :projection_name,
    :last_log_seq,
    :pending_events,
    :is_stale,
    :updated_at,
    :digest,
    :open_failures
  ]

  @type t :: %__MODULE__{
          projection_name: atom(),
          last_log_seq: non_neg_integer(),
          pending_events: non_neg_integer(),
          is_stale: boolean(),
          updated_at: String.t() | nil,
          digest: String.t() | nil,
          open_failures: non_neg_integer()
        }
end

defmodule DecisionGraph.Projector.ProjectionHealth do
  @moduledoc "Per-tenant projection-runtime health summary."

  @enforce_keys [:tenant_id, :event_log_last_seq, :projections, :open_runs]
  defstruct [:tenant_id, :event_log_last_seq, :projections, :open_runs, :full_digest]

  @type t :: %__MODULE__{
          tenant_id: String.t(),
          event_log_last_seq: non_neg_integer(),
          projections: [DecisionGraph.Projector.ProjectionStatus.t()],
          open_runs: [map()],
          full_digest: String.t() | nil
        }
end
