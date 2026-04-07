defmodule AgentmancerWeb.ProjectLive.Index do
  use AgentmancerWeb, :live_view

  alias Agentmancer.Projects
  alias Agentmancer.Projects.Project

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Projects",
       projects: Projects.list_active_projects(),
       form: to_form(Projects.change_project(%Project{}))
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    assign(socket,
      page_title: "New Project",
      show_modal: true,
      form: to_form(Projects.change_project(%Project{}))
    )
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, show_modal: false)
  end

  @impl true
  def handle_event("validate", %{"project" => project_params}, socket) do
    project_params = maybe_generate_slug(project_params)

    changeset =
      %Project{}
      |> Projects.change_project(project_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"project" => project_params}, socket) do
    project_params = maybe_generate_slug(project_params)

    case Projects.create_project(project_params) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project created successfully.")
         |> push_navigate(to: ~p"/projects/#{project.slug}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp maybe_generate_slug(%{"name" => name, "slug" => ""} = params) when name != "" do
    slug =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    Map.put(params, "slug", slug)
  end

  defp maybe_generate_slug(params), do: params

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Projects
        <:subtitle>Manage your agent projects</:subtitle>
        <:actions>
          <.link navigate={~p"/projects/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="size-4" /> New Project
          </.link>
        </:actions>
      </.header>

      <div :if={@projects == []} class="text-base-content/60 py-12 text-center">
        No projects yet. Create your first project to get started.
      </div>

      <div :if={@projects != []} class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mt-6">
        <.link
          :for={project <- @projects}
          navigate={~p"/projects/#{project.slug}"}
          class="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer"
        >
          <div class="card-body">
            <h3 class="card-title text-base">{project.name}</h3>
            <p :if={project.description} class="text-sm text-base-content/60 line-clamp-2">
              {project.description}
            </p>
            <p :if={!project.description} class="text-sm text-base-content/40 italic">
              No description
            </p>
            <div class="text-xs text-base-content/40 mt-2">
              {project.slug}
            </div>
          </div>
        </.link>
      </div>

      <.modal :if={@show_modal} id="new-project-modal" show on_cancel={JS.navigate(~p"/projects")}>
        <h3 class="text-lg font-semibold mb-4">New Project</h3>
        <.form for={@form} id="project-form" phx-change="validate" phx-submit="save">
          <.input field={@form[:name]} type="text" label="Name" required phx-debounce="300" />
          <.input field={@form[:slug]} type="text" label="Slug" required phx-debounce="300" />
          <.input field={@form[:description]} type="textarea" label="Description" />
          <div class="mt-4 flex justify-end gap-2">
            <.link navigate={~p"/projects"} class="btn btn-ghost btn-sm">Cancel</.link>
            <.button variant="primary" phx-disable-with="Creating...">Create Project</.button>
          </div>
        </.form>
      </.modal>
    </Layouts.app>
    """
  end

  defp modal(assigns) do
    ~H"""
    <div
      id={@id}
      class="modal modal-open"
      phx-mounted={@show && show_modal(@id)}
    >
      <div class="modal-box">
        <form method="dialog">
          <button
            class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
            phx-click={@on_cancel}
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </form>
        {render_slot(@inner_block)}
      </div>
      <div class="modal-backdrop" phx-click={@on_cancel}></div>
    </div>
    """
  end

  defp show_modal(js \\ %JS{}, id) do
    js
    |> JS.show(to: "##{id}")
  end
end
