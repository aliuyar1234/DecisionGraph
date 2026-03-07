defmodule DecisionGraphWeb.Endpoint do
  @moduledoc false

  use Phoenix.Endpoint, otp_app: :dg_web

  @session_options [
    store: :cookie,
    key: "_decision_graph_beam_key",
    signing_salt: "phase2-session-salt"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Telemetry, event_prefix: [:decision_graph, :web, :request]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug DecisionGraph.Observability.Plugs.RequestContext
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug DecisionGraphWeb.Router
end
