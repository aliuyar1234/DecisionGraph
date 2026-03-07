import Config

config :dg_store, DecisionGraph.Store.Repo,
  username: "decisiongraph",
  password: "decisiongraph",
  hostname: "localhost",
  database: "decisiongraph_beam_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :dg_store, start_repo: true

config :dg_api,
  admin_controls: %{
    allow_rebuild: true,
    require_reason: true
  },
  operator_console_account_id: "dev-admin",
  rate_limits: %{admin: 60, read: 600, write: 300},
  workflow_defaults: %{
    deadline_risk_warning_minutes: 30,
    default_assigned_role: "admin",
    escalation_assigned_role: "admin",
    exception_review_sla_hours: 4
  },
  service_accounts: [
    %{
      account_id: "dev-reader",
      permissions: [],
      roles: ["reader"],
      tenant_ids: ["default", "release-demo"],
      token: "dev-reader-token"
    },
    %{
      account_id: "dev-writer",
      permissions: ["workflow_assign", "workflow_review"],
      roles: ["writer"],
      tenant_ids: ["default", "release-demo"],
      token: "dev-writer-token"
    },
    %{
      account_id: "dev-admin",
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
      tenant_ids: ["default", "*"],
      token: "dev-admin-token"
    }
  ]

config :dg_web, DecisionGraphWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4100],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "phase2-dev-secret-key-base",
  server: true,
  watchers: []

config :logger, :default_handler, level: :debug
