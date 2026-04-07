defmodule AgentmancerWeb.ProjectLive.Show do
  use AgentmancerWeb, :live_view

  alias Agentmancer.Projects
  alias Agentmancer.Projects.Repository
  alias Agentmancer.Agents
  alias Agentmancer.Workflows
  alias Agentmancer.Vault
  alias Agentmancer.Execution

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    project = Projects.get_project_by_slug!(slug)
    variables = load_project_variables(project.id)

    {:ok,
     assign(socket,
       page_title: project.name,
       project: project,
       repos: Projects.list_repositories(project.id),
       agents: Agents.list_agent_definitions(project.id),
       workflows: Workflows.list_workflow_definitions(project.id),
       runs: Execution.list_runs(project_id: project.id, limit: 5),
       repo_form: to_form(Projects.change_repository(%Repository{})),
       var_key: "",
       var_value: "",
       var_secret: false,
       variables: variables,
       required_vars_status: Vault.required_variables_status(variables),
       optional_variables: Vault.optional_variables(variables),
       scope_id: nil
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save_repo", %{"repository" => repo_params}, socket) do
    repo_params = Map.put(repo_params, "project_id", socket.assigns.project.id)

    case Projects.create_repository(repo_params) do
      {:ok, _repo} ->
        {:noreply,
         socket
         |> put_flash(:info, "Repository added.")
         |> assign(
           repos: Projects.list_repositories(socket.assigns.project.id),
           repo_form: to_form(Projects.change_repository(%Repository{}))
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, repo_form: to_form(changeset))}
    end
  end

  def handle_event("validate_repo", %{"repository" => repo_params}, socket) do
    changeset =
      %Repository{}
      |> Projects.change_repository(repo_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, repo_form: to_form(changeset))}
  end

  def handle_event(
        "save_required_variable",
        %{"key" => key, "value" => value, "secret" => secret},
        socket
      ) do
    project = socket.assigns.project
    {:ok, scope} = Vault.get_or_create_scope(:project, project_id: project.id)

    case Vault.set_variable(scope.id, key, value, is_secret: secret == "true") do
      {:ok, _var} ->
        {:noreply,
         socket
         |> put_flash(:info, "Variable saved.")
         |> assign(scope_id: scope.id)
         |> reload_project_variables()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save variable.")}
    end
  end

  def handle_event("save_variable", %{"key" => key, "value" => value, "secret" => secret}, socket) do
    project = socket.assigns.project
    {:ok, scope} = Vault.get_or_create_scope(:project, project_id: project.id)

    case Vault.set_variable(scope.id, key, value, is_secret: secret == "true") do
      {:ok, _var} ->
        {:noreply,
         socket
         |> put_flash(:info, "Variable saved.")
         |> assign(var_key: "", var_value: "", var_secret: false, scope_id: scope.id)
         |> reload_project_variables()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save variable.")}
    end
  end

  def handle_event("save_variable", %{"key" => key, "value" => value}, socket) do
    handle_event("save_variable", %{"key" => key, "value" => value, "secret" => "false"}, socket)
  end

  def handle_event("delete_variable", %{"id" => id}, socket) do
    case Vault.delete_variable(id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Variable deleted.")
         |> reload_project_variables()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete variable.")}
    end
  end

  defp load_project_variables(project_id) do
    case Vault.get_or_create_scope(:project, project_id: project_id) do
      {:ok, scope} -> Vault.list_variables_for_scope(scope.id)
      _ -> []
    end
  end

  defp reload_project_variables(socket) do
    variables = load_project_variables(socket.assigns.project.id)

    assign(socket,
      variables: variables,
      required_vars_status: Vault.required_variables_status(variables),
      optional_variables: Vault.optional_variables(variables)
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@project.name}
        <:subtitle>{@project.description || "No description"}</:subtitle>
        <:actions>
          <.link navigate={~p"/projects"} class="btn btn-ghost">
            <.icon name="hero-arrow-left" class="size-4" /> Back
          </.link>
        </:actions>
      </.header>

      <div role="tablist" class="tabs tabs-bordered mt-6">
        <.link
          navigate={~p"/projects/#{@project.slug}"}
          class={["tab", @live_action == :show && "tab-active"]}
        >
          Overview
        </.link>
        <.link
          navigate={~p"/projects/#{@project.slug}/repos"}
          class={["tab", @live_action == :repos && "tab-active"]}
        >
          Repositories
        </.link>
        <.link
          navigate={~p"/projects/#{@project.slug}/variables"}
          class={["tab", @live_action == :variables && "tab-active"]}
        >
          Variables
        </.link>
      </div>

      <div class="mt-6">
        <.tab_content
          live_action={@live_action}
          project={@project}
          repos={@repos}
          agents={@agents}
          workflows={@workflows}
          runs={@runs}
          repo_form={@repo_form}
          variables={@variables}
          required_vars_status={@required_vars_status}
          optional_variables={@optional_variables}
          var_key={@var_key}
          var_value={@var_value}
          var_secret={@var_secret}
        />
      </div>
    </Layouts.app>
    """
  end

  defp tab_content(%{live_action: :show} = assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div class="stat bg-base-200 rounded-lg">
        <div class="stat-title">Agents</div>
        <div class="stat-value text-sm">{length(@agents)}</div>
        <div class="stat-actions">
          <.link navigate={~p"/projects/#{@project.slug}/agents"} class="btn btn-ghost">
            View <.icon name="hero-arrow-right" class="size-3" />
          </.link>
        </div>
      </div>

      <div class="stat bg-base-200 rounded-lg">
        <div class="stat-title">Workflows</div>
        <div class="stat-value text-sm">{length(@workflows)}</div>
        <div class="stat-actions">
          <.link navigate={~p"/projects/#{@project.slug}/workflows"} class="btn btn-ghost">
            View <.icon name="hero-arrow-right" class="size-3" />
          </.link>
        </div>
      </div>

      <div class="stat bg-base-200 rounded-lg">
        <div class="stat-title">Repositories</div>
        <div class="stat-value text-sm">{length(@repos)}</div>
        <div class="stat-actions">
          <.link navigate={~p"/projects/#{@project.slug}/repos"} class="btn btn-ghost">
            View <.icon name="hero-arrow-right" class="size-3" />
          </.link>
        </div>
      </div>
    </div>

    <div class="card bg-base-200 mt-6">
      <div class="card-body">
        <h3 class="card-title text-sm">Recent Runs</h3>
        <div :if={@runs == []} class="text-base-content/60 text-sm">
          No runs for this project yet.
        </div>
        <.table :if={@runs != []} id="project-runs" rows={@runs}>
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
    </div>

    <div class="card bg-base-200 mt-6">
      <div class="card-body">
        <h3 class="card-title text-sm">Details</h3>
        <.list>
          <:item title="Slug">{@project.slug}</:item>
          <:item title="Created">{format_dt(@project.inserted_at)}</:item>
        </.list>
      </div>
    </div>
    """
  end

  defp tab_content(%{live_action: :repos} = assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="card bg-base-200">
        <div class="card-body">
          <h3 class="card-title text-sm">Add Repository</h3>
          <.form
            for={@repo_form}
            id="repo-form"
            phx-change="validate_repo"
            phx-submit="save_repo"
            class="flex flex-col gap-2"
          >
            <.input field={@repo_form[:name]} type="text" label="Name" required />
            <.input
              field={@repo_form[:clone_url]}
              type="text"
              label="Clone URL"
              required
              placeholder="https://github.com/org/repo.git"
            />
            <.input
              field={@repo_form[:default_branch]}
              type="text"
              label="Default Branch"
              value="main"
            />
            <.button variant="primary" phx-disable-with="Adding...">Add Repository</.button>
          </.form>
        </div>
      </div>

      <div class="card bg-base-200">
        <div class="card-body">
          <h3 class="card-title text-sm">Repositories</h3>
          <div :if={@repos == []} class="text-base-content/60 text-sm">
            No repositories configured.
          </div>
          <.table :if={@repos != []} id="repos" rows={@repos}>
            <:col :let={repo} label="Name">{repo.name}</:col>
            <:col :let={repo} label="Clone URL">
              <span class="text-xs font-mono">{repo.clone_url}</span>
            </:col>
            <:col :let={repo} label="Branch">{repo.default_branch}</:col>
            <:col :let={repo} label="Last Synced">{format_dt(repo.last_synced_at)}</:col>
          </.table>
        </div>
      </div>
    </div>
    """
  end

  defp tab_content(%{live_action: :variables} = assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="card bg-base-200">
        <div class="card-body">
          <h3 class="card-title text-sm">Required Variables</h3>
          <p class="text-sm text-base-content/60 mb-2">
            Inherits from global scope if not set here.
          </p>
          <div class="space-y-4">
            <div
              :for={req <- @required_vars_status}
              class="flex flex-wrap gap-3 items-end border-b border-base-300/30 pb-4 last:border-0"
            >
              <div class="flex-1 min-w-[200px]">
                <div class="flex items-center gap-2">
                  <span class="font-mono text-sm">{req.key}</span>
                  <span :if={req.configured} class="badge badge-sm badge-success">
                    Configured
                  </span>
                  <span :if={!req.configured} class="badge badge-sm badge-error">
                    Not configured
                  </span>
                </div>
                <p class="text-xs text-base-content/50 mt-1">{req.description}</p>
              </div>
              <form phx-submit="save_required_variable" class="flex gap-2 items-end">
                <input type="hidden" name="key" value={req.key} />
                <input type="hidden" name="secret" value={to_string(req.secret)} />
                <div class="form-control">
                  <input
                    type="password"
                    name="value"
                    required
                    class="input input-bordered w-64"
                    placeholder={if req.configured, do: "Update value...", else: "Enter value..."}
                  />
                </div>
                <button type="submit" class="btn btn-primary">
                  {if req.configured, do: "Update", else: "Save"}
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>

      <div class="card bg-base-200">
        <div class="card-body">
          <h3 class="card-title text-sm">Add Variable</h3>
          <p class="text-sm text-base-content/60 mb-2">
            Custom variables scoped to this project.
          </p>
          <form phx-submit="save_variable" class="flex flex-wrap gap-3 items-end">
            <div class="form-control">
              <label class="label"><span class="label-text">Key</span></label>
              <input
                type="text"
                name="key"
                value={@var_key}
                required
                class="input input-bordered w-48"
              />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Value</span></label>
              <input
                type="text"
                name="value"
                value={@var_value}
                required
                class="input input-bordered w-64"
              />
            </div>
            <div class="form-control">
              <label class="label cursor-pointer gap-2">
                <span class="label-text">Secret</span>
                <input
                  type="checkbox"
                  name="secret"
                  value="true"
                  checked={@var_secret}
                  class="checkbox"
                />
              </label>
            </div>
            <button type="submit" class="btn btn-primary">Save</button>
          </form>
        </div>
      </div>

      <div class="card bg-base-200">
        <div class="card-body">
          <h3 class="card-title text-sm">Custom Variables</h3>
          <div :if={@optional_variables == []} class="text-base-content/60 text-sm">
            No custom variables set.
          </div>
          <.table :if={@optional_variables != []} id="variables" rows={@optional_variables}>
            <:col :let={var} label="Key">{var.key}</:col>
            <:col :let={var} label="Value">
              <span :if={var.is_secret} class="text-base-content/40 italic">***hidden***</span>
              <span :if={!var.is_secret} class="font-mono text-sm">{var.value_ciphertext}</span>
            </:col>
            <:col :let={var} label="Secret">
              <span :if={var.is_secret} class="badge badge-sm badge-warning">secret</span>
            </:col>
            <:action :let={var}>
              <button
                phx-click="delete_variable"
                phx-value-id={var.id}
                class="btn btn-ghost text-error"
                data-confirm="Delete this variable?"
              >
                Delete
              </button>
            </:action>
          </.table>
        </div>
      </div>
    </div>
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
