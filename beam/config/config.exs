import Config

config :dg_store,
  ecto_repos: [DecisionGraph.Store.Repo],
  start_repo: false

config :dg_api,
  admin_controls: %{
    allow_rebuild: false,
    require_reason: true
  },
  deployment_env: to_string(config_env())

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :request_id,
    :trace_id,
    :tenant_id,
    :projection,
    :worker,
    :account_id,
    :api_action,
    :job_id,
    :workflow_id
  ]

config :dg_projector,
  projection_batch_size: 250,
  projection_job_batch_size: 500,
  projection_max_edges: 250,
  projection_max_nodes: 250,
  projection_max_retries: 5,
  projection_partitions: 8,
  projection_poll_interval_ms: 1_000,
  projection_retry_base_ms: 250

config :dg_store, DecisionGraph.Store.Repo,
  maintenance_database: "postgres",
  migration_primary_key: [name: :id, type: :binary_id],
  migration_timestamps: [type: :utc_datetime_usec],
  telemetry_prefix: [:decision_graph, :repo]

config :dg_web, DecisionGraphWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: DecisionGraphWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: DecisionGraphWeb.PubSub,
  live_view: [signing_salt: "phase2-signing-salt"],
  server: false

config :phoenix, :json_library, Jason

config :opentelemetry,
  resource: [
    service: %{
      name: "decisiongraph-beam",
      namespace: "decisiongraph",
      version: "0.1.0"
    }
  ]

import_config "#{config_env()}.exs"
