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

  scope "/", DecisionGraphWeb do
    pipe_through :browser

    live "/", DashboardLive
  end

  scope "/api", DecisionGraphWeb do
    pipe_through :api

    get "/healthz", HealthController, :show
  end
end
