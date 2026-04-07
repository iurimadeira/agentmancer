defmodule Agentmancer.Catalog.CatalogEntry do
  use Agentmancer.Schema

  schema "catalog_entries" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :category, :string, default: "custom"
    field :kind, :string, default: "custom"
    field :tags, {:array, :string}, default: []
    field :icon, :string, default: "hero-cpu-chip"
    field :author, :string
    field :system_prompt, :string
    field :output_schema, :map, default: %{}

    timestamps()
  end

  def changeset(catalog_entry, attrs) do
    catalog_entry
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :category,
      :kind,
      :tags,
      :icon,
      :author,
      :system_prompt,
      :output_schema
    ])
    |> validate_required([:name, :slug, :system_prompt])
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/)
    |> unique_constraint(:slug)
  end
end
