defmodule Agentmancer.Catalog do
  import Ecto.Query
  alias Agentmancer.Repo
  alias Agentmancer.Catalog.CatalogEntry
  alias Agentmancer.Agents

  @valid_kinds ~w(pr_review auto_fix ticket_triage digest custom)

  def list_catalog_entries do
    CatalogEntry
    |> order_by(:name)
    |> Repo.all()
  end

  def list_catalog_entries(opts) when is_list(opts) do
    CatalogEntry
    |> apply_filters(opts)
    |> order_by(:name)
    |> Repo.all()
  end

  def get_catalog_entry!(id), do: Repo.get!(CatalogEntry, id)

  def get_catalog_entry_by_slug(slug), do: Repo.get_by(CatalogEntry, slug: slug)

  def create_catalog_entry(attrs) do
    %CatalogEntry{} |> CatalogEntry.changeset(attrs) |> Repo.insert()
  end

  def update_catalog_entry(%CatalogEntry{} = entry, attrs) do
    entry |> CatalogEntry.changeset(attrs) |> Repo.update()
  end

  def delete_catalog_entry(%CatalogEntry{} = entry) do
    Repo.delete(entry)
  end

  def change_catalog_entry(%CatalogEntry{} = entry, attrs \\ %{}) do
    CatalogEntry.changeset(entry, attrs)
  end

  def list_categories do
    CatalogEntry
    |> select([c], c.category)
    |> distinct(true)
    |> order_by(:category)
    |> Repo.all()
  end

  def install_to_project(%CatalogEntry{} = entry, project_id, runtime_profile_id) do
    kind = if entry.kind in @valid_kinds, do: String.to_existing_atom(entry.kind), else: :custom

    Repo.transaction(fn ->
      {:ok, agent_def} =
        Agents.create_agent_definition(%{
          project_id: project_id,
          name: entry.name,
          slug: entry.slug,
          kind: kind,
          category: entry.category,
          description: entry.description,
          runtime_profile_id: runtime_profile_id,
          template_slug: entry.slug
        })

      {:ok, _version} =
        Agents.create_version(agent_def, %{
          system_prompt: entry.system_prompt,
          output_schema: entry.output_schema || %{},
          change_note: "Installed from catalog: #{entry.name}",
          created_by: "system",
          set_active: true
        })

      Repo.reload!(agent_def)
    end)
  end

  def install_to_project(%CatalogEntry{} = entry, project_id, runtime_profile_id, opts) do
    kind = if entry.kind in @valid_kinds, do: String.to_existing_atom(entry.kind), else: :custom
    name = Keyword.get(opts, :name, entry.name)
    slug = Keyword.get(opts, :slug, entry.slug)

    Repo.transaction(fn ->
      case Agents.create_agent_definition(%{
             project_id: project_id,
             name: name,
             slug: slug,
             kind: kind,
             category: entry.category,
             description: entry.description,
             runtime_profile_id: runtime_profile_id,
             template_slug: entry.slug
           }) do
        {:ok, agent_def} ->
          {:ok, _version} =
            Agents.create_version(agent_def, %{
              system_prompt: entry.system_prompt,
              output_schema: entry.output_schema || %{},
              change_note: "Installed from catalog: #{entry.name}",
              created_by: "system",
              set_active: true
            })

          Repo.reload!(agent_def)

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp apply_filters(query, []), do: query

  defp apply_filters(query, [{:category, category} | rest])
       when is_binary(category) and category != "" do
    query
    |> where([c], c.category == ^category)
    |> apply_filters(rest)
  end

  defp apply_filters(query, [{:search, search} | rest]) when is_binary(search) and search != "" do
    pattern = "%#{search}%"

    query
    |> where([c], ilike(c.name, ^pattern) or ilike(c.description, ^pattern))
    |> apply_filters(rest)
  end

  defp apply_filters(query, [{:tag, tag} | rest]) when is_binary(tag) and tag != "" do
    query
    |> where([c], ^tag in c.tags)
    |> apply_filters(rest)
  end

  defp apply_filters(query, [_ | rest]), do: apply_filters(query, rest)
end
