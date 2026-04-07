defmodule AgentmancerWeb.AgentLive.Index do
  use AgentmancerWeb, :live_view

  alias Agentmancer.Projects
  alias Agentmancer.Agents
  alias Agentmancer.Agents.AgentDefinition

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    project = Projects.get_project_by_slug!(slug)
    agents = Agents.list_agent_definitions(project.id)
    profiles = Agents.list_runtime_profiles(project.id)

    {:ok,
     assign(socket,
       page_title: "Agents - #{project.name}",
       project: project,
       agents: agents,
       runtime_profiles: profiles,
       form: to_form(Agents.change_agent_definition(%AgentDefinition{})),
       kind_filter: nil
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
  def handle_event("validate", %{"agent_definition" => params}, socket) do
    params = maybe_generate_slug(params)

    changeset =
      %AgentDefinition{}
      |> Agents.change_agent_definition(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"agent_definition" => params}, socket) do
    params =
      params
      |> maybe_generate_slug()
      |> Map.put("project_id", socket.assigns.project.id)

    case Agents.create_agent_definition(params) do
      {:ok, agent} ->
        {:noreply,
         socket
         |> put_flash(:info, "Agent created.")
         |> push_navigate(to: ~p"/projects/#{socket.assigns.project.slug}/agents/#{agent.slug}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("filter_kind", %{"kind" => ""}, socket) do
    {:noreply,
     assign(socket,
       kind_filter: nil,
       agents: Agents.list_agent_definitions(socket.assigns.project.id)
     )}
  end

  def handle_event("filter_kind", %{"kind" => kind}, socket) do
    agents =
      socket.assigns.project.id
      |> Agents.list_agent_definitions()
      |> Enum.filter(&(to_string(&1.kind) == kind))

    {:noreply, assign(socket, kind_filter: kind, agents: agents)}
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
        Agents
        <:subtitle>{@project.name}</:subtitle>
        <:actions>
          <.link navigate={~p"/projects/#{@project.slug}"} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left" class="size-4" /> Project
          </.link>
          <.link navigate={~p"/projects/#{@project.slug}/agents/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="size-4" /> New Agent
          </.link>
        </:actions>
      </.header>

      <div class="mt-4 mb-4">
        <form phx-change="filter_kind">
          <select name="kind" class="select select-sm select-bordered">
            <option value="">All kinds</option>
            <option
              :for={kind <- ~w(pr_review auto_fix ticket_triage digest custom)}
              value={kind}
              selected={@kind_filter == kind}
            >
              {kind}
            </option>
          </select>
        </form>
      </div>

      <div :if={@agents == []} class="text-base-content/60 py-8 text-center">
        No agents defined. Create one to get started.
      </div>

      <.table :if={@agents != []} id="agents" rows={@agents}>
        <:col :let={agent} label="Name">{agent.name}</:col>
        <:col :let={agent} label="Kind">
          <span class="badge badge-sm badge-outline">{agent.kind}</span>
        </:col>
        <:col :let={agent} label="Slug">
          <span class="text-xs font-mono">{agent.slug}</span>
        </:col>
        <:action :let={agent}>
          <.link
            navigate={~p"/projects/#{@project.slug}/agents/#{agent.slug}"}
            class="link link-primary text-sm"
          >
            View
          </.link>
        </:action>
      </.table>

      <.modal
        :if={@show_modal}
        id="new-agent-modal"
        show
        on_cancel={JS.navigate(~p"/projects/#{@project.slug}/agents")}
      >
        <h3 class="text-lg font-semibold mb-4">New Agent</h3>
        <.form for={@form} id="agent-form" phx-change="validate" phx-submit="save">
          <.input field={@form[:name]} type="text" label="Name" required phx-debounce="300" />
          <.input field={@form[:slug]} type="text" label="Slug" required phx-debounce="300" />
          <.input field={@form[:description]} type="textarea" label="Description" />
          <.input
            field={@form[:kind]}
            type="select"
            label="Kind"
            options={[
              {"PR Review", :pr_review},
              {"Auto Fix", :auto_fix},
              {"Ticket Triage", :ticket_triage},
              {"Digest", :digest},
              {"Custom", :custom}
            ]}
            required
          />
          <.input
            field={@form[:runtime_profile_id]}
            type="select"
            label="Runtime Profile"
            options={Enum.map(@runtime_profiles, &{&1.name, &1.id})}
            prompt="Select a profile"
            required
          />
          <div class="mt-4 flex justify-end gap-2">
            <.link navigate={~p"/projects/#{@project.slug}/agents"} class="btn btn-ghost btn-sm">
              Cancel
            </.link>
            <.button variant="primary" phx-disable-with="Creating...">Create Agent</.button>
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
end
