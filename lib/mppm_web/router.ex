defmodule MppmWeb.Router do
  use MppmWeb, :router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :with_session do
    plug :put_root_layout, {MppmWeb.LayoutView, :root}
    plug Mppm.Session.UserSession
  end

  pipeline :auth do
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/auth", MppmWeb do
    pipe_through [:browser, :auth]

    get "/login.html", AuthController, :login
    get "/logout", AuthController, :logout
    get "/:service/callback", AuthController, :callback
  end

  scope "/", MppmWeb do
    pipe_through [:browser, :with_session]

    live "/", DashboardLive
    live_dashboard "/dashboard"
    live "/system_overview", SystemOverviewLive
    live "/app_settings", AppSettingsLive
    live "/:server_login", ServerManagerLive
  end

end
