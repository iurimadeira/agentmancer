defmodule AgentmancerWeb.DashboardLive.Index do
  use AgentmancerWeb, :live_view

  alias Agentmancer.Projects
  alias Agentmancer.Execution

  @impl true
  def mount(_params, _session, socket) do
    projects = Projects.list_active_projects()
    active_runs = Execution.count_runs(status: :running)

    recent_completions =
      Execution.count_recent_completions(DateTime.add(DateTime.utc_now(), -24, :hour))

    recent_runs = Execution.list_runs(limit: 10)

    {:ok,
     assign(socket,
       page_title: "Dashboard",
       projects: projects,
       project_count: length(projects),
       active_runs: active_runs,
       recent_completions: recent_completions,
       recent_runs: recent_runs
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Dashboard
        <:subtitle>Overview of your Agentmancer instance</:subtitle>
      </.header>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-6">
        <div class="stat bg-base-200 rounded-lg">
          <div class="stat-title">Projects</div>
          <div class="stat-value">{@project_count}</div>
          <div class="stat-actions">
            <.link navigate={~p"/projects"} class="btn btn-primary">View all</.link>
          </div>
        </div>

        <div class="stat bg-base-200 rounded-lg">
          <div class="stat-title">Active Runs</div>
          <div class="stat-value text-warning">{@active_runs}</div>
          <div class="stat-actions">
            <.link navigate={~p"/runs"} class="btn btn-primary">View runs</.link>
          </div>
        </div>

        <div class="stat bg-base-200 rounded-lg">
          <div class="stat-title">Completed (24h)</div>
          <div class="stat-value text-success">{@recent_completions}</div>
        </div>
      </div>

      <div class="card bg-base-200 mt-8">
        <div class="card-body">
          <div class="flex items-center justify-between mb-4">
            <h3 class="card-title text-sm">Recent Runs</h3>
            <.link navigate={~p"/runs"} class="btn btn-ghost">View all</.link>
          </div>

          <div :if={@recent_runs == []} class="text-base-content/60 py-8 text-center">
            No runs yet. Create a project and workflow to get started.
          </div>

          <.table :if={@recent_runs != []} id="recent-runs" rows={@recent_runs}>
            <:col :let={run} label="Number">#{run.number}</:col>
            <:col :let={run} label="Status">
              <.status_badge status={run.status} />
            </:col>
            <:col :let={run} label="Started">
              {format_datetime(run.started_at || run.inserted_at)}
            </:col>
            <:action :let={run}>
              <.link navigate={~p"/runs/#{run.id}"} class="link link-primary text-sm">View</.link>
            </:action>
          </.table>
        </div>
      </div>

      <div class="card bg-base-200 mt-6">
        <div class="card-body">
          <h3 class="card-title text-sm">Quick Actions</h3>
          <div class="flex gap-3">
            <.link navigate={~p"/projects/new"} class="btn btn-primary">
              <.icon name="hero-plus" class="size-4" /> New Project
            </.link>
            <.link navigate={~p"/runs"} class="btn btn-ghost">
              <.icon name="hero-play-circle" class="size-4" /> All Runs
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm",
      status_color(@status)
    ]}>
      {@status}
    </span>
    """
  end

  defp status_color(:success), do: "badge-success"
  defp status_color(:failure), do: "badge-error"
  defp status_color(:running), do: "badge-warning"
  defp status_color(:preparing), do: "badge-warning"
  defp status_color(:pending), do: "badge-ghost"
  defp status_color(:cancelled), do: "badge-ghost"
  defp status_color(:timed_out), do: "badge-error"
  defp status_color(:stale), do: "badge-ghost"
  defp status_color(_), do: "badge-ghost"

  defp format_datetime(nil), do: "-"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  end
end
