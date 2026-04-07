defmodule Mix.Tasks.Agentmancer.SeedCatalog do
  @shortdoc "Seeds the agent catalog from priv/templates"
  @moduledoc """
  Seeds default agent catalog entries from the template files in priv/templates.

  Reads registry.json for metadata and loads prompt/schema files for each entry.
  Upserts by slug — running again updates existing entries with latest content.

      mix agentmancer.seed_catalog
  """

  use Mix.Task

  @requirements ["app.start"]

  alias Agentmancer.Catalog

  @impl Mix.Task
  def run(_args) do
    registry = load_registry()
    templates = Map.fetch!(registry, "templates")

    {created, updated} =
      Enum.reduce(templates, {0, 0}, fn template, {c, u} ->
        slug = Map.fetch!(template, "slug")
        prompt = load_prompt(slug)
        schema = load_schema(slug)

        attrs = %{
          name: Map.fetch!(template, "name"),
          slug: slug,
          description: Map.get(template, "description"),
          category: Map.get(template, "category", "custom"),
          kind: Map.get(template, "kind", "custom"),
          tags: Map.get(template, "tags", []),
          icon: Map.get(template, "icon", "hero-cpu-chip"),
          author: Map.get(template, "author"),
          system_prompt: prompt,
          output_schema: schema,
          suggested_trigger: Map.get(template, "suggested_trigger", %{})
        }

        case Catalog.get_catalog_entry_by_slug(slug) do
          nil ->
            case Catalog.create_catalog_entry(attrs) do
              {:ok, _} ->
                Mix.shell().info("  Created: #{slug}")
                {c + 1, u}

              {:error, changeset} ->
                Mix.shell().error("  Failed to create #{slug}: #{inspect(changeset.errors)}")
                {c, u}
            end

          existing ->
            case Catalog.update_catalog_entry(existing, attrs) do
              {:ok, _} ->
                Mix.shell().info("  Updated: #{slug}")
                {c, u + 1}

              {:error, changeset} ->
                Mix.shell().error("  Failed to update #{slug}: #{inspect(changeset.errors)}")
                {c, u}
            end
        end
      end)

    Mix.shell().info("\nCatalog seeded: #{created} created, #{updated} updated.")
  end

  defp load_registry do
    path = templates_dir("registry.json")

    if File.exists?(path) do
      path |> File.read!() |> Jason.decode!()
    else
      Mix.raise("Registry file not found: #{path}")
    end
  end

  defp load_prompt(slug) do
    path = templates_dir(Path.join(["prompts", slug, "prompt.md"]))

    if File.exists?(path) do
      File.read!(path)
    else
      Mix.shell().error("  Warning: prompt file not found for #{slug}, using placeholder")
      "Default system prompt for #{slug}. Edit this in the catalog."
    end
  end

  defp load_schema(slug) do
    path = templates_dir(Path.join(["prompts", slug, "schema.json"]))

    if File.exists?(path) do
      path |> File.read!() |> Jason.decode!()
    else
      %{}
    end
  end

  defp templates_dir(filename) do
    Application.app_dir(:agentmancer, ["priv", "templates", filename])
  end
end
