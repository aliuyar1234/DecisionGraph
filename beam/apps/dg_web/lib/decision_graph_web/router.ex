defmodule DecisionGraphWeb.Router do
  use DecisionGraphWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_reader do
    plug :accepts, ["json"]
    plug DecisionGraphWeb.Plugs.ApiAuth, roles: ["reader", "writer", "admin"]
    plug DecisionGraphWeb.Plugs.RateLimit, scope: :read
  end

  pipeline :api_writer do
    plug :accepts, ["json"]
    plug DecisionGraphWeb.Plugs.ApiAuth, roles: ["writer", "admin"]
    plug DecisionGraphWeb.Plugs.RateLimit, scope: :write
  end

  pipeline :api_admin do
    plug :accepts, ["json"]
    plug DecisionGraphWeb.Plugs.ApiAuth, roles: ["admin"]
    plug DecisionGraphWeb.Plugs.RateLimit, scope: :admin
  end

  scope "/", DecisionGraphWeb do
    pipe_through :browser

    live "/", DashboardLive
    live "/bootstrap", BootstrapLive
  end

  scope "/api", DecisionGraphWeb do
    pipe_through :api

    get "/healthz", HealthController, :show
  end

  scope "/api/v1", DecisionGraphWeb do
    pipe_through :api_writer

    post "/events", EventController, :create
    post "/workflow-studio/traces/:trace_id/reviews", WorkflowStudioController, :create_review
    post "/workflows/:workflow_id/actions", WorkflowController, :act
  end

  scope "/api/v1", DecisionGraphWeb do
    pipe_through :api_reader

    get "/traces/:trace_id", TraceController, :show
    get "/graph/context", GraphController, :context
    get "/graph/edges", GraphController, :edges
    get "/precedents", PrecedentController, :index
    get "/projections/health", ProjectionController, :show
    get "/workflow-studio/templates", WorkflowStudioController, :index
    get "/workflow-studio/traces/:trace_id", WorkflowStudioController, :show
    get "/workflows", WorkflowController, :index
    get "/workflows/:workflow_id", WorkflowController, :show
  end

  scope "/api/v1/admin", DecisionGraphWeb do
    pipe_through :api_admin

    post "/replays", ReplayController, :create
    get "/replays/:job_id", ReplayController, :show
    post "/replays/:job_id/cancel", ReplayController, :cancel
    get "/workflows/:workflow_id/export", WorkflowController, :export
  end
end
