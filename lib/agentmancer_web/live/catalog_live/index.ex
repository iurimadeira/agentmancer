defmodule AgentmancerWeb.CatalogLive.Index do
  use AgentmancerWeb, :live_view

  alias Agentmancer.Catalog
  alias Agentmancer.Catalog.CatalogEntry

  @impl true
  def mount(_params, _session, socket) do
    entries = Catalog.list_catalog_entries()
    categories = Catalog.list_categories()

    {:ok,
     assign(socket,
       page_title: "Agent Catalog",
       entries: entries,
       categories: categories,
       category_filter: nil,
       search_query: "",
       form: to_form(Catalog.change_catalog_entry(%CatalogEntry{})),
       show_modal: false
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action)}
  end

  defp apply_action(socket, :new) do
    assign(socket, show_modal: true)
  end

  defp apply_action(socket, :index) do
    assign(socket, show_modal: false)
  end

  @impl true
  def handle_event("validate", %{"catalog_entry" => params}, socket) do
    params = maybe_generate_slug(params)

    changeset =
      %CatalogEntry{}
      |> Catalog.change_catalog_entry(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"catalog_entry" => params}, socket) do
    params = maybe_generate_slug(params)
    params = normalize_tags(params)

    case Catalog.create_catalog_entry(params) do
      {:ok, entry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Catalog entry created.")
         |> push_navigate(to: ~p"/catalog/#{entry.slug}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("filter", params, socket) do
    category = Map.get(params, "category", "")
    search = Map.get(params, "search", "")

    filters =
      []
      |> then(fn f -> if category != "", do: [{:category, category} | f], else: f end)
      |> then(fn f -> if search != "", do: [{:search, search} | f], else: f end)

    entries =
      if filters == [],
        do: Catalog.list_catalog_entries(),
        else: Catalog.list_catalog_entries(filters)

    {:noreply, assign(socket, entries: entries, category_filter: category, search_query: search)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    entry = Catalog.get_catalog_entry!(id)

    case Catalog.delete_catalog_entry(entry) do
      {:ok, _} ->
        entries = Catalog.list_catalog_entries()

        {:noreply,
         socket
         |> put_flash(:info, "\"#{entry.name}\" deleted.")
         |> assign(entries: entries)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete entry.")}
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

  defp normalize_tags(%{"tags" => tags} = params) when is_binary(tags) do
    normalized =
      tags
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    Map.put(params, "tags", normalized)
  end

  defp normalize_tags(params), do: params

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Agent Catalog
        <:subtitle>Global agent template library</:subtitle>
        <:actions>
          <.link navigate={~p"/catalog/new"} class="btn btn-primary">
            <.icon name="hero-plus" class="size-4" /> New Entry
          </.link>
        </:actions>
      </.header>

      <div class="mt-6 space-y-6">
        <div class="card bg-base-200">
          <div class="card-body">
            <form phx-change="filter" class="flex flex-wrap gap-3 items-end">
              <div class="form-control">
                <label class="label"><span class="label-text">Category</span></label>
                <select name="category" class="select select-bordered">
                  <option value="">All categories</option>
                  <option
                    :for={cat <- @categories}
                    value={cat}
                    selected={@category_filter == cat}
                  >
                    {cat}
                  </option>
                </select>
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Search</span></label>
                <input
                  type="text"
                  name="search"
                  value={@search_query}
                  placeholder="Search templates..."
                  class="input input-bordered"
                  phx-debounce="300"
                />
              </div>
            </form>
          </div>
        </div>

        <div :if={@entries == []} class="text-base-content/60 py-8 text-center">
          No catalog entries found. Add one to get started.
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <.link
            :for={entry <- @entries}
            navigate={~p"/catalog/#{entry.slug}"}
            class="card bg-base-200 hover:border-primary/50 transition-colors cursor-pointer"
          >
            <div class="card-body">
              <div class="flex items-center gap-2">
                <.icon name={entry.icon || "hero-cpu-chip"} class="size-5 text-primary" />
                <h3 class="card-title text-sm">{entry.name}</h3>
              </div>
              <div class="flex gap-1 mt-1">
                <span class="badge badge-sm badge-outline">{entry.category}</span>
                <span
                  :for={tag <- Enum.take(entry.tags || [], 2)}
                  class="badge badge-sm badge-ghost"
                >
                  {tag}
                </span>
              </div>
              <p class="text-sm text-base-content/60 mt-2 line-clamp-2">
                {entry.description}
              </p>
              <div :if={entry.author} class="text-xs text-base-content/40 mt-2">
                by {entry.author}
              </div>
            </div>
          </.link>
        </div>
      </div>

      <.modal
        :if={@show_modal}
        id="new-entry-modal"
        on_cancel={JS.navigate(~p"/catalog")}
      >
        <h3 class="text-lg font-semibold mb-4">New Catalog Entry</h3>
        <.form for={@form} id="entry-form" phx-change="validate" phx-submit="save">
          <.input field={@form[:name]} type="text" label="Name" required phx-debounce="300" />
          <.input field={@form[:slug]} type="text" label="Slug" required phx-debounce="300" />
          <.input field={@form[:description]} type="textarea" label="Description" />
          <.input field={@form[:category]} type="text" label="Category" value="custom" />
          <.input
            field={@form[:kind]}
            type="select"
            label="Kind"
            options={[
              {"PR Review", "pr_review"},
              {"Auto Fix", "auto_fix"},
              {"Ticket Triage", "ticket_triage"},
              {"Digest", "digest"},
              {"Custom", "custom"}
            ]}
          />
          <.input field={@form[:icon]} type="text" label="Icon" value="hero-cpu-chip" />
          <.input field={@form[:author]} type="text" label="Author" />
          <.input
            field={@form[:system_prompt]}
            type="textarea"
            label="System Prompt"
            required
          />
          <div class="mt-4 flex justify-end gap-2">
            <.link navigate={~p"/catalog"} class="btn btn-ghost">Cancel</.link>
            <.button variant="primary" phx-disable-with="Creating...">Create Entry</.button>
          </div>
        </.form>
      </.modal>
    </Layouts.app>
    """
  end

  defp modal(assigns) do
    ~H"""
    <div id={@id} class="modal modal-open">
      <div class="modal-box max-w-2xl">
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
