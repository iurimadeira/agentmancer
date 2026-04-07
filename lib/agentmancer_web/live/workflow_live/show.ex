defmodule AgentmancerWeb.WorkflowLive.Show do
  use AgentmancerWeb, :live_view

  alias Agentmancer.Projects
  alias Agentmancer.Workflows
  alias Agentmancer.Execution

  @impl true
  def mount(%{"slug" => slug, "workflow_slug" => workflow_slug}, _session, socket) do
    project = Projects.get_project_by_slug!(slug)
    workflow = Workflows.get_workflow_definition_by_slug!(workflow_slug)
    bindings = Workflows.list_workflow_bindings(workflow.id)
    triggers = Workflows.list_triggers(workflow.id)
    runs = Execution.list_runs(project_id: project.id, limit: 10)

    {:ok,
     assign(socket,
       page_title: "#{workflow.name} - #{project.name}",
       project: project,
       workflow: workflow,
       bindings: bindings,
       triggers: triggers,
       runs: runs
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_trigger", %{"id" => id}, socket) do
    trigger = Workflows.get_trigger!(id)

    case Workflows.update_trigger(trigger, %{enabled: !trigger.enabled}) do
      {:ok, _trigger} ->
        triggers = Workflows.list_triggers(socket.assigns.workflow.id)
        {:noreply, assign(socket, triggers: triggers)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update trigger.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@workflow.name}
        <:subtitle>
          {@workflow.description}
          <span class={[
            "badge badge-sm ml-2",
            if(@workflow.enabled, do: "badge-success", else: "badge-ghost")
          ]}>
            {if @workflow.enabled, do: "Enabled", else: "Disabled"}
          </span>
        </:subtitle>
        <:actions>
          <.link navigate={~p"/projects/#{@project.slug}/workflows"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="size-4" /> Workflows
          </.link>
        </:actions>
      </.header>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-sm">Bindings</h3>
            <div :if={@bindings == []} class="text-base-content/60 text-sm">
              No bindings configured.
            </div>
            <div
              :for={binding <- @bindings}
              class="flex items-center gap-3 py-2 border-b border-base-300 last:border-0"
            >
              <span class="badge badge-sm">{binding.position}</span>
              <div class="flex-1 min-w-0">
                <div class="text-sm font-medium">{binding.agent_definition.name}</div>
                <div :if={binding.repository} class="text-xs text-base-content/60">
                  Repo: {binding.repository.name}
                </div>
              </div>
              <span class={[
                "badge badge-xs",
                if(binding.enabled, do: "badge-success", else: "badge-ghost")
              ]}>
                {if binding.enabled, do: "on", else: "off"}
              </span>
            </div>
          </div>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-sm">Triggers</h3>
            <div :if={@triggers == []} class="text-base-content/60 text-sm">
              No triggers configured.
            </div>
            <div
              :for={trigger <- @triggers}
              class="flex items-center gap-3 py-2 border-b border-base-300 last:border-0"
            >
              <span class="badge badge-sm badge-outline">{trigger.type}</span>
              <div class="flex-1 min-w-0">
                <div class="text-sm">{trigger.name}</div>
                <div :if={trigger.last_triggered_at} class="text-xs text-base-content/60">
                  Last: {Calendar.strftime(trigger.last_triggered_at, "%Y-%m-%d %H:%M")}
                </div>
              </div>
              <div class="form-control">
                <input
                  type="checkbox"
                  class="toggle toggle-sm toggle-success"
                  checked={trigger.enabled}
                  phx-click="toggle_trigger"
                  phx-value-id={trigger.id}
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-6">
        <h3 class="font-semibold mb-3">Recent Runs</h3>
        <div :if={@runs == []} class="text-base-content/60 text-sm">No runs yet.</div>
        <.table :if={@runs != []} id="workflow-runs" rows={@runs}>
          <:col :let={run} label="#">{run.number}</:col>
          <:col :let={run} label="Status">
            <span class={["badge badge-sm", run_status_color(run.status)]}>{run.status}</span>
          </:col>
          <:col :let={run} label="Started">{format_dt(run.started_at || run.inserted_at)}</:col>
          <:action :let={run}>
            <.link navigate={~p"/runs/#{run.id}"} class="link link-primary text-sm">View</.link>
          </:action>
        </.table>
      </div>

      <div :if={@workflow.config && @workflow.config != %{}} class="mt-6">
        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-sm">Config</h3>
            <pre class="text-xs bg-base-300 p-3 rounded-lg overflow-x-auto"><code>{Jason.encode!(@workflow.config, pretty: true)}</code></pre>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp run_status_color(:success), do: "badge-success"
  defp run_status_color(:failure), do: "badge-error"
  defp run_status_color(:running), do: "badge-warning"
  defp run_status_color(:preparing), do: "badge-warning"
  defp run_status_color(:pending), do: "badge-ghost"
  defp run_status_color(:cancelled), do: "badge-ghost"
  defp run_status_color(_), do: "badge-ghost"

  defp format_dt(nil), do: "-"
  defp format_dt(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
end
