import Config

config :dg_store, DecisionGraph.Store.Repo,
  username: "decisiongraph",
  password: "decisiongraph",
  hostname: "localhost",
  database: "decisiongraph_beam_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :dg_store, start_repo: false

config :dg_api,
  admin_controls: %{
    allow_rebuild: true,
    require_reason: true
  },
  operator_console_account_id: "admin-test",
  rate_limits: %{admin: 20, read: 100, write: 50},
  workflow_defaults: %{
    deadline_risk_warning_minutes: 30,
    default_assigned_role: "admin",
    escalation_assigned_role: "admin",
    exception_review_sla_hours: 4
  },
  service_accounts: [
    %{
      account_id: "reader-test",
      permissions: [],
      roles: ["reader"],
      tenant_ids: ["tenant-a", "default"],
      token: "reader-test-token"
    },
    %{
      account_id: "writer-test",
      permissions: ["workflow_assign", "workflow_review"],
      roles: ["writer"],
      tenant_ids: ["tenant-a", "default"],
      token: "writer-test-token"
    },
    %{
      account_id: "admin-test",
      permissions: [
        "projection_rebuild",
        "projection_replay",
        "workflow_assign",
        "workflow_escalate",
        "workflow_export",
        "workflow_override",
        "workflow_review"
      ],
      roles: ["admin"],
      tenant_ids: ["tenant-a", "default"],
      token: "admin-test-token"
    }
  ]

config :dg_web, DecisionGraphWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4102],
  secret_key_base: "phase2-test-secret-key-base",
  server: false

config :dg_projector, projection_poll_interval_ms: 60_000

config :logger, :default_handler, level: :warning
