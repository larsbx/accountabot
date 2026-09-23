defmodule AccountabotWeb.Router do
  use AccountabotWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {AccountabotWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  # NOTE: the CPA id in the path is not authentication. Put real sign-in in
  # front of these routes before exposing them beyond localhost.
  scope "/", AccountabotWeb do
    pipe_through(:browser)

    get("/", PageController, :home)
    live("/onboarding/:cpa_id", OnboardingLive)
    live("/review/:cpa_id", ReviewLive)
  end
end
