import Config

config :dg_store, DecisionGraph.Store.Repo,
  username: "decisiongraph",
  password: "decisiongraph",
  hostname: "localhost",
  database: "decisiongraph_beam_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :dg_store, start_repo: false

config :dg_web, DecisionGraphWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4102],
  secret_key_base: "phase2-test-secret-key-base",
  server: false

config :logger, :default_handler, level: :warning
