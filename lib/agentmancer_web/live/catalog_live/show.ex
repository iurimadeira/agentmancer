defmodule AgentmancerWeb.CatalogLive.Show do
  use AgentmancerWeb, :live_view

  alias Agentmancer.Catalog

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    entry =
      Catalog.get_catalog_entry_by_slug(slug) ||
        raise Ecto.NoResultsError, queryable: Agentmancer.Catalog.CatalogEntry

    {:ok,
     assign(socket,
       page_title: entry.name,
       entry: entry,
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
      {:noreply, push_patch(socket, to: ~p"/catalog/#{socket.assigns.entry.slug}")}
    else
      {:noreply, push_patch(socket, to: ~p"/catalog/#{socket.assigns.entry.slug}/edit")}
    end
  end

  def handle_event("update", %{"catalog_entry" => params}, socket) do
    params = normalize_tags(params)

    case Catalog.update_catalog_entry(socket.assigns.entry, params) do
      {:ok, entry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Catalog entry updated.")
         |> assign(entry: entry, editing: false)
         |> push_patch(to: ~p"/catalog/#{entry.slug}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update entry.")}
    end
  end

  def handle_event("delete", _params, socket) do
    case Catalog.delete_catalog_entry(socket.assigns.entry) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Catalog entry deleted.")
         |> push_navigate(to: ~p"/catalog")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete entry.")}
    end
  end

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
        <div class="flex items-center gap-2">
          <.icon name={@entry.icon || "hero-cpu-chip"} class="size-6 text-primary" />
          {@entry.name}
        </div>
        <:subtitle>
          <span class="badge badge-sm badge-outline">{@entry.category}</span>
          <span class="badge badge-sm badge-ghost">{@entry.kind}</span>
          {@entry.description}
        </:subtitle>
        <:actions>
          <.link navigate={~p"/catalog"} class="btn btn-ghost">
            <.icon name="hero-arrow-left" class="size-4" /> Catalog
          </.link>
          <button phx-click="toggle_edit" class="btn btn-primary">
            {if @editing, do: "Cancel", else: "Edit"}
          </button>
          <button
            phx-click="delete"
            data-confirm="Delete this catalog entry?"
            class="btn btn-error btn-outline"
          >
            Delete
          </button>
        </:actions>
      </.header>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mt-6">
        <div class="lg:col-span-2 space-y-6">
          <%= if @editing do %>
            <div class="card bg-base-200 border-2 border-primary">
              <div class="card-body">
                <h3 class="card-title text-sm">Edit Catalog Entry</h3>
                <form phx-submit="update" class="space-y-3 mt-2">
                  <input type="hidden" name="catalog_entry[slug]" value={@entry.slug} />
                  <div class="form-control">
                    <label class="label"><span class="label-text">Name</span></label>
                    <input
                      type="text"
                      name="catalog_entry[name]"
                      value={@entry.name}
                      required
                      class="input input-bordered"
                    />
                  </div>
                  <div class="form-control">
                    <label class="label"><span class="label-text">Description</span></label>
                    <textarea
                      name="catalog_entry[description]"
                      class="textarea textarea-bordered"
                      rows="2"
                    >{@entry.description}</textarea>
                  </div>
                  <div class="grid grid-cols-2 gap-3">
                    <div class="form-control">
                      <label class="label"><span class="label-text">Category</span></label>
                      <input
                        type="text"
                        name="catalog_entry[category]"
                        value={@entry.category}
                        class="input input-bordered"
                      />
                    </div>
                    <div class="form-control">
                      <label class="label"><span class="label-text">Kind</span></label>
                      <select name="catalog_entry[kind]" class="select select-bordered">
                        <option
                          :for={kind <- ~w(pr_review auto_fix ticket_triage digest custom)}
                          value={kind}
                          selected={@entry.kind == kind}
                        >
                          {kind}
                        </option>
                      </select>
                    </div>
                  </div>
                  <div class="grid grid-cols-2 gap-3">
                    <div class="form-control">
                      <label class="label"><span class="label-text">Icon</span></label>
                      <input
                        type="text"
                        name="catalog_entry[icon]"
                        value={@entry.icon}
                        class="input input-bordered"
                      />
                    </div>
                    <div class="form-control">
                      <label class="label"><span class="label-text">Author</span></label>
                      <input
                        type="text"
                        name="catalog_entry[author]"
                        value={@entry.author}
                        class="input input-bordered"
                      />
                    </div>
                  </div>
                  <div class="form-control">
                    <label class="label">
                      <span class="label-text">Tags (comma-separated)</span>
                    </label>
                    <input
                      type="text"
                      name="catalog_entry[tags]"
                      value={Enum.join(@entry.tags || [], ", ")}
                      class="input input-bordered"
                      placeholder="review, security, quality"
                    />
                  </div>
                  <div class="form-control">
                    <label class="label"><span class="label-text">System Prompt</span></label>
                    <textarea
                      name="catalog_entry[system_prompt]"
                      required
                      rows="12"
                      class="textarea textarea-bordered w-full font-mono text-sm"
                    >{@entry.system_prompt}</textarea>
                  </div>
                  <div class="flex justify-end gap-2">
                    <button type="button" phx-click="toggle_edit" class="btn btn-ghost">
                      Cancel
                    </button>
                    <button type="submit" class="btn btn-primary">Save Changes</button>
                  </div>
                </form>
              </div>
            </div>
          <% else %>
            <div class="card bg-base-200">
              <div class="card-body">
                <h3 class="card-title text-sm">System Prompt</h3>
                <pre class="whitespace-pre-wrap text-sm bg-base-300 p-4 rounded-lg max-h-96 overflow-y-auto mt-2"><code>{@entry.system_prompt}</code></pre>
              </div>
            </div>

            <div
              :if={@entry.output_schema && @entry.output_schema != %{}}
              class="card bg-base-200"
            >
              <div class="card-body">
                <h3 class="card-title text-sm">Output Schema</h3>
                <pre class="text-xs bg-base-300 p-3 rounded-lg overflow-x-auto mt-2"><code>{Jason.encode!(@entry.output_schema, pretty: true)}</code></pre>
              </div>
            </div>
          <% end %>
        </div>

        <div class="space-y-6">
          <div class="card bg-base-200">
            <div class="card-body">
              <h3 class="card-title text-sm">Details</h3>
              <.list>
                <:item title="Slug">
                  <span class="font-mono text-sm">{@entry.slug}</span>
                </:item>
                <:item title="Category">{@entry.category}</:item>
                <:item title="Kind">{@entry.kind}</:item>
                <:item title="Author">{@entry.author || "-"}</:item>
                <:item title="Icon">{@entry.icon || "-"}</:item>
              </.list>
            </div>
          </div>

          <div :if={@entry.tags && @entry.tags != []} class="card bg-base-200">
            <div class="card-body">
              <h3 class="card-title text-sm">Tags</h3>
              <div class="flex flex-wrap gap-1 mt-2">
                <span :for={tag <- @entry.tags} class="badge badge-sm badge-outline">
                  {tag}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
