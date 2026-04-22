defmodule AgentmancerWeb.WorkflowLive.Index do
  use AgentmancerWeb, :live_view

  alias Agentmancer.Projects
  alias Agentmancer.Workflows
  alias Agentmancer.Workflows.WorkflowDefinition

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    project = Projects.get_project_by_slug!(slug)
    workflows = Workflows.list_workflow_definitions(project.id)

    {:ok,
     assign(socket,
       page_title: "Workflows - #{project.name}",
       project: project,
       workflows: workflows,
       form: to_form(Workflows.change_workflow_definition(%WorkflowDefinition{}))
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    assign(socket, show_modal: true)
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, show_modal: false)
  end

  @impl true
  def handle_event("validate", %{"workflow_definition" => params}, socket) do
    params = maybe_generate_slug(params)

    changeset =
      %WorkflowDefinition{}
      |> Workflows.change_workflow_definition(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"workflow_definition" => params}, socket) do
    params =
      params
      |> maybe_generate_slug()
      |> Map.put("project_id", socket.assigns.project.id)

    case Workflows.create_workflow_definition(params) do
      {:ok, workflow} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workflow created.")
         |> push_navigate(
           to: ~p"/projects/#{socket.assigns.project.slug}/workflows/#{workflow.slug}"
         )}

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
        Workflows
        <:subtitle>{@project.name}</:subtitle>
        <:actions>
          <.link navigate={~p"/projects/#{@project.slug}"} class="btn btn-ghost">
            <.icon name="hero-arrow-left" class="size-4" /> Project
          </.link>
          <.link
            navigate={~p"/projects/#{@project.slug}/workflows/new"}
            class="btn btn-primary"
          >
            <.icon name="hero-plus" class="size-4" /> New Workflow
          </.link>
        </:actions>
      </.header>

      <div class="card bg-base-200 mt-6">
        <div class="card-body">
          <div :if={@workflows == []} class="text-base-content/60 py-8 text-center">
            No workflows defined. Create one to get started.
          </div>

          <.table :if={@workflows != []} id="workflows" rows={@workflows}>
            <:col :let={wf} label="Name">{wf.name}</:col>
            <:col :let={wf} label="Slug">
              <span class="text-xs font-mono">{wf.slug}</span>
            </:col>
            <:col :let={wf} label="Enabled">
              <span class={[
                "badge badge-sm",
                if(wf.enabled, do: "badge-success", else: "badge-ghost")
              ]}>
                {if wf.enabled, do: "Yes", else: "No"}
              </span>
            </:col>
            <:action :let={wf}>
              <.link
                navigate={~p"/projects/#{@project.slug}/workflows/#{wf.slug}"}
                class="link link-primary text-sm"
              >
                View
              </.link>
            </:action>
          </.table>
        </div>
      </div>

      <.modal
        :if={@show_modal}
        id="new-workflow-modal"
        show
        on_cancel={JS.navigate(~p"/projects/#{@project.slug}/workflows")}
      >
        <h3 class="text-lg font-semibold mb-4">New Workflow</h3>
        <.form for={@form} id="workflow-form" phx-change="validate" phx-submit="save">
          <.input field={@form[:name]} type="text" label="Name" required phx-debounce="300" />
          <.input field={@form[:slug]} type="text" label="Slug" required phx-debounce="300" />
          <.input field={@form[:description]} type="textarea" label="Description" />
          <div class="mt-4 flex justify-end gap-2">
            <.link navigate={~p"/projects/#{@project.slug}/workflows"} class="btn btn-ghost">
              Cancel
            </.link>
            <.button variant="primary" phx-disable-with="Creating...">Create Workflow</.button>
          </div>
        </.form>
      </.modal>
    </Layouts.app>
    """
  end

  defp modal(assigns) do
    ~H"""
    <div id={@id} class="modal modal-open">
      <div class="modal-box">
        <form method="dialog">
          <button
            class="btn btn-circle btn-ghost absolute right-2 top-2"
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
end
