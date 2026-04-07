defmodule AgentmancerWeb.RunLive.Index do
  use AgentmancerWeb, :live_view

  alias Agentmancer.Execution
  alias Agentmancer.Projects

  @per_page 20

  @impl true
  def mount(_params, _session, socket) do
    projects = Projects.list_active_projects()

    {:ok,
     assign(socket,
       page_title: "Runs",
       projects: projects,
       status_filter: nil,
       project_filter: nil,
       page: 0,
       per_page: @per_page,
       runs: Execution.list_runs(limit: @per_page, offset: 0)
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", params, socket) do
    status =
      case params["status"] do
        "" -> nil
        s -> s
      end

    project_id =
      case params["project_id"] do
        "" -> nil
        id -> id
      end

    opts =
      [limit: @per_page, offset: 0]
      |> maybe_put(:status, status)
      |> maybe_put(:project_id, project_id)

    runs = Execution.list_runs(opts)

    {:noreply,
     assign(socket, runs: runs, status_filter: status, project_filter: project_id, page: 0)}
  end

  def handle_event("next_page", _params, socket) do
    page = socket.assigns.page + 1

    opts =
      [limit: @per_page, offset: page * @per_page]
      |> maybe_put(:status, socket.assigns.status_filter)
      |> maybe_put(:project_id, socket.assigns.project_filter)

    runs = Execution.list_runs(opts)

    if runs == [] do
      {:noreply, socket}
    else
      {:noreply, assign(socket, runs: runs, page: page)}
    end
  end

  def handle_event("prev_page", _params, socket) do
    page = max(socket.assigns.page - 1, 0)

    opts =
      [limit: @per_page, offset: page * @per_page]
      |> maybe_put(:status, socket.assigns.status_filter)
      |> maybe_put(:project_id, socket.assigns.project_filter)

    {:noreply, assign(socket, runs: Execution.list_runs(opts), page: page)}
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Runs
        <:subtitle>All agent execution runs</:subtitle>
      </.header>

      <form phx-change="filter" class="flex gap-3 mt-4 mb-4 items-end">
        <div class="form-control">
          <label class="label"><span class="label-text text-xs">Status</span></label>
          <select name="status" class="select select-sm select-bordered">
            <option value="">All statuses</option>
            <option
              :for={s <- ~w(pending preparing running success failure cancelled timed_out stale)}
              value={s}
              selected={@status_filter == s}
            >
              {s}
            </option>
          </select>
        </div>
        <div class="form-control">
          <label class="label"><span class="label-text text-xs">Project</span></label>
          <select name="project_id" class="select select-sm select-bordered">
            <option value="">All projects</option>
            <option :for={p <- @projects} value={p.id} selected={@project_filter == p.id}>
              {p.name}
            </option>
          </select>
        </div>
      </form>

      <div :if={@runs == []} class="text-base-content/60 py-8 text-center">
        No runs found.
      </div>

      <.table :if={@runs != []} id="runs" rows={@runs}>
        <:col :let={run} label="#">{run.number}</:col>
        <:col :let={run} label="Status">
          <span class={["badge badge-sm", status_color(run.status)]}>{run.status}</span>
        </:col>
        <:col :let={run} label="Branch">
          <span :if={run.branch} class="text-xs font-mono">{run.branch}</span>
          <span :if={!run.branch} class="text-base-content/40">-</span>
        </:col>
        <:col :let={run} label="Started">{format_dt(run.started_at || run.inserted_at)}</:col>
        <:col :let={run} label="Duration">{format_duration(run)}</:col>
        <:action :let={run}>
          <.link navigate={~p"/runs/#{run.id}"} class="link link-primary text-sm">View</.link>
        </:action>
      </.table>

      <div class="flex justify-center gap-2 mt-4">
        <button :if={@page > 0} phx-click="prev_page" class="btn btn-sm btn-ghost">
          <.icon name="hero-chevron-left" class="size-4" /> Previous
        </button>
        <span class="btn btn-sm btn-ghost no-animation">Page {@page + 1}</span>
        <button :if={length(@runs) == @per_page} phx-click="next_page" class="btn btn-sm btn-ghost">
          Next <.icon name="hero-chevron-right" class="size-4" />
        </button>
      </div>
    </Layouts.app>
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

  defp format_dt(nil), do: "-"
  defp format_dt(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  defp format_duration(%{started_at: nil}), do: "-"

  defp format_duration(%{started_at: started, completed_at: nil}) do
    seconds = DateTime.diff(DateTime.utc_now(), started, :second)
    format_seconds(seconds)
  end

  defp format_duration(%{started_at: started, completed_at: completed}) do
    seconds = DateTime.diff(completed, started, :second)
    format_seconds(seconds)
  end

  defp format_seconds(s) when s < 60, do: "#{s}s"
  defp format_seconds(s) when s < 3600, do: "#{div(s, 60)}m #{rem(s, 60)}s"
  defp format_seconds(s), do: "#{div(s, 3600)}h #{div(rem(s, 3600), 60)}m"
end
