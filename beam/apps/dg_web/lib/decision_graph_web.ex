defmodule DecisionGraphWeb do
  @moduledoc false

  def controller do
    quote do
      use Phoenix.Controller, formats: [:json]

      import Plug.Conn
      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView, layout: false
      unquote(html_helpers())
      unquote(verified_routes())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.Component
      import Phoenix.HTML
    end
  end

  defp verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: DecisionGraphWeb.Endpoint,
        router: DecisionGraphWeb.Router,
        statics: []
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
