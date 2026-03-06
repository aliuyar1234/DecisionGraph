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

config :dg_web, DecisionGraphWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4100],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "phase2-dev-secret-key-base",
  server: true,
  watchers: []

config :logger, :default_handler, level: :debug
