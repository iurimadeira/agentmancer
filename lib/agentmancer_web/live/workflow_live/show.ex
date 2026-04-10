defmodule AgentmancerWeb.WorkflowLive.Show do
  use AgentmancerWeb, :live_view

  alias Agentmancer.Execution
  alias Agentmancer.Projects
  alias Agentmancer.RuntimeProfiles
  alias Agentmancer.Skills
  alias Agentmancer.Workflows

  @impl true
  def mount(%{"slug" => slug, "workflow_slug" => workflow_slug}, _session, socket) do
    project = Projects.get_project_by_slug!(slug)
    workflow = Workflows.get_workflow_definition_by_slug!(project.id, workflow_slug)
    binding = Workflows.first_workflow_binding(workflow.id)
    repos = Projects.list_repositories(project.id)
    runtime_profiles = RuntimeProfiles.list_runtime_profiles(project.id)
    global_skills = Skills.list_global_skills()
    selected_repo_id = (binding && binding.repository_id) || first_repo_id(repos)
    local_skills = load_local_skills(repos, selected_repo_id)

    {:ok,
     assign(socket,
       page_title: "#{workflow.name} - #{project.name}",
       project: project,
       workflow: workflow,
       binding: binding,
       repos: repos,
       triggers: Workflows.list_triggers(workflow.id),
       runs:
         Execution.list_runs(
           project_id: project.id,
           workflow_definition_id: workflow.id,
           limit: 10
         ),
       runtime_profiles: runtime_profiles,
       global_skills: global_skills,
       local_skills: local_skills,
       selected_repo_id: selected_repo_id,
       binding_form: build_binding_form(binding, selected_repo_id),
       runtime_form: build_runtime_form(workflow)
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("binding_change", %{"binding" => params}, socket) do
    selected_repo_id = blank_to_nil(params["repository_id"]) || socket.assigns.selected_repo_id
    local_skills = load_local_skills(socket.assigns.repos, selected_repo_id)

    active_options =
      skill_options(params["skill_source"], socket.assigns.global_skills, local_skills)

    params =
      if Enum.any?(active_options, &(&1.slug == params["skill_slug"])) do
        params
      else
        Map.put(params, "skill_slug", "")
      end

    {:noreply,
     assign(socket,
       selected_repo_id: selected_repo_id,
       local_skills: local_skills,
       binding_form: to_form(params, as: :binding)
     )}
  end

  def handle_event("save_binding", %{"binding" => params}, socket) do
    attrs =
      params
      |> Map.put("project_id", socket.assigns.project.id)
      |> Map.put("workflow_definition_id", socket.assigns.workflow.id)
      |> Map.put("position", (socket.assigns.binding && socket.assigns.binding.position) || 1)

    result =
      case socket.assigns.binding do
        nil -> Workflows.create_workflow_binding(attrs)
        binding -> Workflows.update_workflow_binding(binding, attrs)
      end

    case result do
      {:ok, _binding} ->
        workflow =
          Workflows.get_workflow_definition_by_slug!(
            socket.assigns.project.id,
            socket.assigns.workflow.slug
          )

        binding = Workflows.first_workflow_binding(workflow.id)
        local_skills = load_local_skills(socket.assigns.repos, binding.repository_id)

        {:noreply,
         socket
         |> put_flash(:info, "Workflow skill saved.")
         |> assign(
           workflow: workflow,
           binding: binding,
           selected_repo_id: binding.repository_id,
           local_skills: local_skills,
           binding_form: build_binding_form(binding, binding.repository_id)
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, binding_form: to_form(changeset, as: :binding))}
    end
  end

  def handle_event("save_runtime", %{"workflow_runtime" => params}, socket) do
    runtime_profile_id = blank_to_nil(params["runtime_profile_id"])

    case Workflows.update_workflow_definition(socket.assigns.workflow, %{
           runtime_profile_id: runtime_profile_id
         }) do
      {:ok, workflow} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workflow runtime saved.")
         |> assign(workflow: workflow, runtime_form: build_runtime_form(workflow))}

      {:error, changeset} ->
        {:noreply, assign(socket, runtime_form: to_form(changeset, as: :workflow_runtime))}
    end
  end

  def handle_event("toggle_trigger", %{"id" => id}, socket) do
    trigger = Workflows.get_trigger!(id)

    case Workflows.update_trigger(trigger, %{enabled: !trigger.enabled}) do
      {:ok, _trigger} ->
        {:noreply, assign(socket, triggers: Workflows.list_triggers(socket.assigns.workflow.id))}

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
          <.link navigate={~p"/projects/#{@project.slug}/workflows"} class="btn btn-ghost">
            <.icon name="hero-arrow-left" class="size-4" /> Workflows
          </.link>
          <.link navigate={~p"/projects/#{@project.slug}/skills"} class="btn btn-ghost">
            <.icon name="hero-sparkles" class="size-4" /> Skills
          </.link>
        </:actions>
      </.header>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-sm">Current Skill</h3>
            <div :if={@binding} class="mt-2">
              <.list>
                <:item title="Source">{skill_source_label(@binding.skill_source)}</:item>
                <:item title="Slug">
                  <span class="font-mono text-sm">{@binding.skill_slug}</span>
                </:item>
                <:item title="Repository">
                  {if @binding.repository, do: @binding.repository.name, else: "-"}
                </:item>
              </.list>
            </div>
            <div :if={!@binding} class="text-base-content/60 text-sm">
              No skill is configured yet for this workflow.
            </div>
          </div>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-sm">Runtime</h3>
            <div class="text-sm text-base-content/60 mb-3">
              {runtime_summary(@workflow, @project)}
            </div>
            <.form for={@runtime_form} id="workflow-runtime-form" phx-submit="save_runtime">
              <.input
                field={@runtime_form[:runtime_profile_id]}
                type="select"
                label="Workflow Runtime Override"
                options={Enum.map(@runtime_profiles, &{&1.name, &1.id})}
                prompt="Use project default"
              />
              <.button variant="primary">Save Runtime</.button>
            </.form>
          </div>
        </div>
      </div>

      <div class="card bg-base-200 mt-6">
        <div class="card-body">
          <div class="flex items-start justify-between gap-4">
            <div>
              <h3 class="card-title text-sm">Configure Skill</h3>
              <p class="text-sm text-base-content/60 mt-1">
                Global skills come from AgentMancer. Repository skills are discovered from <span class="font-mono text-xs">skills/*/SKILL.md</span>.
              </p>
            </div>
            <.link navigate={~p"/projects/#{@project.slug}/skills"} class="btn btn-ghost btn-sm">
              Browse Skills
            </.link>
          </div>

          <.form
            for={@binding_form}
            id="workflow-binding-form"
            phx-change="binding_change"
            phx-submit="save_binding"
            class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4"
          >
            <.input
              field={@binding_form[:repository_id]}
              type="select"
              label="Repository"
              options={Enum.map(@repos, &{&1.name, &1.id})}
              prompt="Select a repository"
            />
            <.input
              field={@binding_form[:skill_source]}
              type="select"
              label="Source"
              options={[{"Global", :global}, {"Repository", :repository}]}
            />
            <.input
              field={@binding_form[:skill_slug]}
              type="select"
              label="Skill"
              options={
                skill_options(
                  @binding_form[:skill_source].value,
                  @global_skills,
                  @local_skills
                )
                |> Enum.map(&{"#{&1.name} (#{&1.slug})", &1.slug})
              }
              prompt="Select a skill"
            />
            <div class="md:col-span-3 flex justify-end">
              <.button variant="primary">Save Skill</.button>
            </div>
          </.form>

          <div
            :if={
              @binding_form[:skill_source].value in ["repository", :repository] and
                @local_skills == []
            }
            class="text-sm text-base-content/60 mt-3"
          >
            No repository-local skills found on the selected repository's default branch.
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
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

        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-sm">Recent Runs</h3>
            <div :if={@runs == []} class="text-base-content/60 text-sm">No runs yet.</div>
            <.table :if={@runs != []} id="workflow-runs" rows={@runs}>
              <:col :let={run} label="#">{run.number}</:col>
              <:col :let={run} label="Status">
                <span class={["badge badge-sm", run_status_color(run.status)]}>{run.status}</span>
              </:col>
              <:col :let={run} label="Skill">
                {run.skill_name || Skills.titleize_slug(run.skill_slug || "")}
              </:col>
              <:col :let={run} label="Started">{format_dt(run.started_at || run.inserted_at)}</:col>
              <:action :let={run}>
                <.link navigate={~p"/runs/#{run.id}"} class="link link-primary text-sm">View</.link>
              </:action>
            </.table>
          </div>
        </div>
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

  defp build_binding_form(nil, repo_id) do
    to_form(
      %{
        "repository_id" => repo_id || "",
        "skill_source" => "global",
        "skill_slug" => ""
      },
      as: :binding
    )
  end

  defp build_binding_form(binding, _repo_id) do
    to_form(
      %{
        "repository_id" => binding.repository_id || "",
        "skill_source" => to_string(binding.skill_source),
        "skill_slug" => binding.skill_slug || ""
      },
      as: :binding
    )
  end

  defp build_runtime_form(workflow) do
    to_form(%{"runtime_profile_id" => workflow.runtime_profile_id || ""}, as: :workflow_runtime)
  end

  defp load_local_skills(_repos, nil), do: []

  defp load_local_skills(repos, repo_id) do
    case Enum.find(repos, &(&1.id == repo_id)) do
      nil -> []
      repo -> Skills.list_repository_skills(repo)
    end
  end

  defp skill_options(skill_source, _global_skills, local_skills)
       when skill_source in ["repository", :repository],
       do: local_skills

  defp skill_options(_skill_source, global_skills, _local_skills), do: global_skills

  defp first_repo_id([repo | _]), do: repo.id
  defp first_repo_id([]), do: nil

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp runtime_summary(%{runtime_profile: %{name: name}}, _project),
    do: "Workflow override: #{name}"

  defp runtime_summary(_workflow, project) do
    case RuntimeProfiles.default_runtime_profile(project) do
      %{name: name} -> "Project default: #{name}"
      _ -> "No runtime profile configured."
    end
  end

  defp skill_source_label(:global), do: "Global"
  defp skill_source_label(:repository), do: "Repository"
  defp skill_source_label(_), do: "-"

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
