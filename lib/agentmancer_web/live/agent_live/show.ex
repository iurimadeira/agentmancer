defmodule AgentmancerWeb.AgentLive.Show do
  use AgentmancerWeb, :live_view

  alias Agentmancer.Projects
  alias Agentmancer.Agents
  alias Agentmancer.Repo

  @impl true
  def mount(%{"slug" => slug, "agent_slug" => agent_slug}, _session, socket) do
    project = Projects.get_project_by_slug!(slug)

    agent =
      Agents.get_agent_definition_by_slug!(agent_slug)
      |> Repo.preload([:runtime_profile, :active_version])

    versions = Agents.list_versions(agent.id)

    {:ok,
     assign(socket,
       page_title: "#{agent.name} - #{project.name}",
       project: project,
       agent: agent,
       versions: versions,
       active_version: agent.active_version,
       new_prompt: "",
       change_note: "",
       editing: false
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    case socket.assigns.live_action do
      :edit -> {:noreply, assign(socket, editing: true)}
      _ -> {:noreply, assign(socket, editing: false)}
    end
  end

  @impl true
  def handle_event("toggle_edit", _params, socket) do
    if socket.assigns.editing do
      {:noreply,
       push_patch(socket,
         to: ~p"/projects/#{socket.assigns.project.slug}/agents/#{socket.assigns.agent.slug}"
       )}
    else
      {:noreply,
       push_patch(socket,
         to: ~p"/projects/#{socket.assigns.project.slug}/agents/#{socket.assigns.agent.slug}/edit"
       )}
    end
  end

  def handle_event("create_version", %{"system_prompt" => prompt, "change_note" => note}, socket) do
    agent = socket.assigns.agent

    attrs = %{
      system_prompt: prompt,
      change_note: note,
      created_by: socket.assigns.current_scope.user.email,
      set_active: true
    }

    case Agents.create_version(agent, attrs) do
      {:ok, version} ->
        agent =
          Agents.get_agent_definition!(agent.id)
          |> Repo.preload([:runtime_profile, :active_version])

        {:noreply,
         socket
         |> put_flash(:info, "Version #{version.version_number} created and set as active.")
         |> assign(
           agent: agent,
           active_version: agent.active_version,
           versions: Agents.list_versions(agent.id),
           new_prompt: "",
           change_note: "",
           editing: false
         )
         |> push_patch(to: ~p"/projects/#{socket.assigns.project.slug}/agents/#{agent.slug}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create version.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@agent.name}
        <:subtitle>
          <span class="badge badge-sm badge-outline">{@agent.kind}</span>
          {@agent.description}
        </:subtitle>
        <:actions>
          <.link navigate={~p"/projects/#{@project.slug}/agents"} class="btn btn-ghost">
            <.icon name="hero-arrow-left" class="size-4" /> Agents
          </.link>
          <button phx-click="toggle_edit" class="btn btn-primary">
            {if @editing, do: "Cancel", else: "Edit / New Version"}
          </button>
        </:actions>
      </.header>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mt-6">
        <div class="lg:col-span-2 space-y-6">
          <div class="card bg-base-200">
            <div class="card-body">
              <h3 class="card-title text-sm">Active System Prompt</h3>
              <div :if={@active_version} class="mt-2">
                <pre class="whitespace-pre-wrap text-sm bg-base-300 p-4 rounded-lg max-h-96 overflow-y-auto"><code>{@active_version.system_prompt}</code></pre>
                <div class="mt-2 text-xs text-base-content/60">
                  Version {@active_version.version_number}
                  {if @active_version.change_note, do: " - #{@active_version.change_note}", else: ""}
                </div>
              </div>
              <div :if={!@active_version} class="text-base-content/60 italic text-sm mt-2">
                No active version. Create one below.
              </div>
            </div>
          </div>

          <div :if={@active_version && @active_version.output_schema} class="card bg-base-200">
            <div class="card-body">
              <h3 class="card-title text-sm">Output Schema</h3>
              <pre class="text-xs bg-base-300 p-3 rounded-lg overflow-x-auto"><code>{Jason.encode!(@active_version.output_schema, pretty: true)}</code></pre>
            </div>
          </div>

          <div :if={@editing} class="card bg-base-200 border-2 border-primary">
            <div class="card-body">
              <h3 class="card-title text-sm">Create New Version</h3>
              <form phx-submit="create_version" class="space-y-3 mt-2">
                <div class="form-control">
                  <label class="label"><span class="label-text">System Prompt</span></label>
                  <textarea
                    name="system_prompt"
                    required
                    rows="10"
                    class="textarea textarea-bordered w-full font-mono text-sm"
                    placeholder="Enter the system prompt..."
                  >{@active_version && @active_version.system_prompt}</textarea>
                </div>
                <div class="form-control">
                  <label class="label"><span class="label-text">Change Note</span></label>
                  <input
                    type="text"
                    name="change_note"
                    class="input input-bordered"
                    placeholder="What changed?"
                  />
                </div>
                <button type="submit" class="btn btn-primary">
                  Create Version & Set Active
                </button>
              </form>
            </div>
          </div>
        </div>

        <div class="space-y-6">
          <div :if={@agent.runtime_profile} class="card bg-base-200">
            <div class="card-body">
              <h3 class="card-title text-sm">Runtime Profile</h3>
              <.list>
                <:item title="Name">{@agent.runtime_profile.name}</:item>
                <:item title="Engine">{@agent.runtime_profile.engine}</:item>
                <:item title="Model">{@agent.runtime_profile.model || "-"}</:item>
                <:item title="Timeout">{@agent.runtime_profile.timeout_seconds}s</:item>
              </.list>
            </div>
          </div>

          <div class="card bg-base-200">
            <div class="card-body">
              <h3 class="card-title text-sm">Version History</h3>
              <div :if={@versions == []} class="text-base-content/60 text-sm">No versions yet.</div>
              <div
                :for={v <- @versions}
                class="flex items-center gap-3 py-2 border-b border-base-300 last:border-0"
              >
                <span class={[
                  "badge badge-sm",
                  @active_version && v.id == @active_version.id && "badge-primary",
                  (!@active_version || v.id != @active_version.id) && "badge-ghost"
                ]}>
                  v{v.version_number}
                </span>
                <div class="flex-1 min-w-0">
                  <div class="text-sm truncate">{v.change_note || "No note"}</div>
                  <div class="text-xs text-base-content/50">
                    {Calendar.strftime(v.inserted_at, "%Y-%m-%d %H:%M")}
                    {if v.created_by, do: " by #{v.created_by}", else: ""}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
