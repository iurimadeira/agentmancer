defmodule Agentmancer.Repo.Migrations.AddSuggestedTriggerToCatalogEntries do
  use Ecto.Migration

  def change do
    alter table(:catalog_entries) do
      add :suggested_trigger, :map, default: %{}
    end
  end
end
