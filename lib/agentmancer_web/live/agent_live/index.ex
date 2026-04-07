defmodule AgentmancerWeb.AgentLive.Index do
  use AgentmancerWeb, :live_view

  alias Agentmancer.Projects
  alias Agentmancer.Agents
  alias Agentmancer.Agents.AgentDefinition
  alias Agentmancer.Catalog

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
       kind_filter: nil,
       catalog_entries: [],
       selected_entry: nil,
       install_form: nil
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    assign(socket, show_modal: true)
  end

  defp apply_action(socket, :catalog, _params) do
    entries = Catalog.list_catalog_entries()

    assign(socket,
      show_modal: false,
      catalog_entries: entries,
      selected_entry: nil,
      install_form: nil
    )
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

  def handle_event("select_entry", %{"id" => id}, socket) do
    entry = Catalog.get_catalog_entry!(id)

    slug =
      entry.slug
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    {:noreply,
     assign(socket,
       selected_entry: entry,
       install_form: %{"name" => entry.name, "slug" => slug, "runtime_profile_id" => ""}
     )}
  end

  def handle_event("cancel_install", _params, socket) do
    {:noreply, assign(socket, selected_entry: nil, install_form: nil)}
  end

  def handle_event("install_entry", params, socket) do
    entry = socket.assigns.selected_entry
    project = socket.assigns.project
    profile_id = params["runtime_profile_id"]
    name = params["name"] || entry.name
    slug = params["slug"] || entry.slug

    if profile_id == "" do
      {:noreply, put_flash(socket, :error, "Please select a runtime profile.")}
    else
      case Catalog.install_to_project(entry, project.id, profile_id, name: name, slug: slug) do
        {:ok, agent} ->
          {:noreply,
           socket
           |> put_flash(:info, "Agent \"#{agent.name}\" installed from catalog.")
           |> push_navigate(to: ~p"/projects/#{project.slug}/agents/#{agent.slug}")}

        {:error, changeset} ->
          errors = format_errors(changeset)

          {:noreply, put_flash(socket, :error, "Failed to install: #{errors}")}
      end
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

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    |> Enum.map_join(", ", fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
  end

  defp format_errors(_), do: "unknown error"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <%= if @live_action == :catalog do %>
        {render_catalog(assigns)}
      <% else %>
        {render_agents(assigns)}
      <% end %>
    </Layouts.app>
    """
  end

  defp render_agents(assigns) do
    ~H"""
    <.header>
      Agents
      <:subtitle>{@project.name}</:subtitle>
      <:actions>
        <.link navigate={~p"/projects/#{@project.slug}"} class="btn btn-ghost">
          <.icon name="hero-arrow-left" class="size-4" /> Project
        </.link>
        <.link navigate={~p"/projects/#{@project.slug}/agents/catalog"} class="btn btn-ghost">
          <.icon name="hero-book-open" class="size-4" /> From Catalog
        </.link>
        <.link navigate={~p"/projects/#{@project.slug}/agents/new"} class="btn btn-primary">
          <.icon name="hero-plus" class="size-4" /> New Agent
        </.link>
      </:actions>
    </.header>

    <div class="card bg-base-200 mt-6">
      <div class="card-body">
        <form phx-change="filter_kind" class="mb-4">
          <select name="kind" class="select select-bordered">
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
      </div>
    </div>

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
          <.link navigate={~p"/projects/#{@project.slug}/agents"} class="btn btn-ghost">
            Cancel
          </.link>
          <.button variant="primary" phx-disable-with="Creating...">Create Agent</.button>
        </div>
      </.form>
    </.modal>
    """
  end

  defp render_catalog(assigns) do
    ~H"""
    <.header>
      Install from Catalog
      <:subtitle>{@project.name}</:subtitle>
      <:actions>
        <.link navigate={~p"/projects/#{@project.slug}/agents"} class="btn btn-ghost">
          <.icon name="hero-arrow-left" class="size-4" /> Agents
        </.link>
      </:actions>
    </.header>

    <div :if={@catalog_entries == []} class="text-base-content/60 py-12 text-center mt-6">
      No catalog entries available. Add some in the
      <.link navigate={~p"/catalog"} class="link link-primary">Catalog</.link>
      first.
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mt-6">
      <div
        :for={entry <- @catalog_entries}
        class="card bg-base-200 hover:border-primary/50 transition-colors"
      >
        <div class="card-body">
          <div class="flex items-center gap-2">
            <.icon name={entry.icon || "hero-cpu-chip"} class="size-5 text-primary" />
            <h3 class="card-title text-sm">{entry.name}</h3>
          </div>
          <div class="flex gap-1 mt-1">
            <span class="badge badge-sm badge-outline">{entry.category}</span>
            <span :for={tag <- Enum.take(entry.tags || [], 2)} class="badge badge-sm badge-ghost">
              {tag}
            </span>
          </div>
          <p class="text-sm text-base-content/60 mt-2 line-clamp-2">{entry.description}</p>
          <div class="card-actions justify-end mt-3">
            <button
              phx-click="select_entry"
              phx-value-id={entry.id}
              class="btn btn-primary btn-sm"
            >
              Install
            </button>
          </div>
        </div>
      </div>
    </div>

    <.modal
      :if={@selected_entry}
      id="install-modal"
      on_cancel={JS.push("cancel_install")}
    >
      <h3 class="text-lg font-semibold mb-4">
        Install "{@selected_entry.name}"
      </h3>
      <form phx-submit="install_entry" class="space-y-3">
        <div class="form-control">
          <label class="label"><span class="label-text">Agent Name</span></label>
          <input
            type="text"
            name="name"
            value={@install_form["name"]}
            required
            class="input input-bordered"
          />
        </div>
        <div class="form-control">
          <label class="label"><span class="label-text">Slug</span></label>
          <input
            type="text"
            name="slug"
            value={@install_form["slug"]}
            required
            class="input input-bordered"
          />
        </div>
        <div class="form-control">
          <label class="label"><span class="label-text">Runtime Profile</span></label>
          <select name="runtime_profile_id" required class="select select-bordered">
            <option value="">Select a profile</option>
            <option :for={p <- @runtime_profiles} value={p.id}>{p.name}</option>
          </select>
        </div>
        <div class="mt-4 flex justify-end gap-2">
          <button type="button" phx-click="cancel_install" class="btn btn-ghost">
            Cancel
          </button>
          <button type="submit" class="btn btn-primary" phx-disable-with="Installing...">
            Install Agent
          </button>
        </div>
      </form>
    </.modal>
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
