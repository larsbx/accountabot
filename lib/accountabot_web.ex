defmodule AccountabotWeb do
  @moduledoc "Web layer: the CPA-facing surfaces, rendered from `Accountabot.Profile`."

  def router do
    quote do
      use Phoenix.Router, helpers: false
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html]
      import Plug.Conn
      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView
      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import AccountabotWeb.Components
      alias AccountabotWeb.Layouts
      alias Phoenix.LiveView.JS
      unquote(verified_routes())
    end
  end

  defp verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: AccountabotWeb.Endpoint,
        router: AccountabotWeb.Router,
        statics: []
    end
  end

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])
end
