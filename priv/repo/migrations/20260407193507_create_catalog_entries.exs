defmodule Agentmancer.Repo.Migrations.CreateCatalogEntries do
  use Ecto.Migration

  def change do
    create table(:catalog_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :category, :string, null: false, default: "custom"
      add :kind, :string, null: false, default: "custom"
      add :tags, {:array, :string}, default: []
      add :icon, :string, default: "hero-cpu-chip"
      add :author, :string
      add :system_prompt, :text, null: false
      add :output_schema, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:catalog_entries, [:slug])

    alter table(:agent_definitions) do
      add :category, :string
      add :template_slug, :string
    end
  end
end
