import Config

deployment_env =
  System.get_env("DECISION_GRAPH_DEPLOYMENT_ENV") ||
    if(config_env() == :prod, do: "prod", else: Atom.to_string(config_env()))

config :dg_api, deployment_env: deployment_env

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      "ecto://decisiongraph:decisiongraph@localhost/decisiongraph_beam_prod"

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      "phase2-prod-secret-key-base"

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4100")
  pool_size = String.to_integer(System.get_env("POOL_SIZE") || "10")

  config :dg_store, DecisionGraph.Store.Repo,
    url: database_url,
    pool_size: pool_size

  config :dg_store, start_repo: true

  config :dg_web, DecisionGraphWeb.Endpoint,
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base,
    server: System.get_env("PHX_SERVER") in ["1", "true", "TRUE"],
    url: [host: host, port: 443, scheme: "https"]
end
