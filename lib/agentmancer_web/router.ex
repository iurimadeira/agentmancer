defmodule AgentmancerWeb.Router do
  use AgentmancerWeb, :router

  import AgentmancerWeb.UserAuth
  import Oban.Web.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AgentmancerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/webhooks", AgentmancerWeb do
    pipe_through :api

    post "/:path_token", WebhookController, :receive
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:agentmancer, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AgentmancerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", AgentmancerWeb do
    pipe_through [:browser, :require_authenticated_user]

    oban_dashboard("/oban")

    live_session :require_authenticated_user,
      on_mount: [{AgentmancerWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

      live "/", DashboardLive.Index, :index
      live "/projects", ProjectLive.Index, :index
      live "/projects/new", ProjectLive.Index, :new
      live "/projects/:slug", ProjectLive.Show, :show
      live "/projects/:slug/repos", ProjectLive.Show, :repos
      live "/projects/:slug/variables", ProjectLive.Show, :variables
      live "/catalog", CatalogLive.Index, :index
      live "/catalog/new", CatalogLive.Index, :new
      live "/catalog/:slug", CatalogLive.Show, :show
      live "/catalog/:slug/edit", CatalogLive.Show, :edit

      live "/projects/:slug/agents", AgentLive.Index, :index
      live "/projects/:slug/agents/new", AgentLive.Index, :new
      live "/projects/:slug/agents/catalog", AgentLive.Index, :catalog
      live "/projects/:slug/agents/:agent_slug", AgentLive.Show, :show
      live "/projects/:slug/agents/:agent_slug/edit", AgentLive.Show, :edit
      live "/projects/:slug/workflows", WorkflowLive.Index, :index
      live "/projects/:slug/workflows/new", WorkflowLive.Index, :new
      live "/projects/:slug/workflows/:workflow_slug", WorkflowLive.Show, :show
      live "/runs", RunLive.Index, :index
      live "/runs/:id", RunLive.Show, :show
      live "/settings", SettingLive.Index, :index
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", AgentmancerWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{AgentmancerWeb.UserAuth, :mount_current_scope}] do
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
