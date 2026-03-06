import Config

config :dg_web, DecisionGraphWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, :default_handler, level: :info
