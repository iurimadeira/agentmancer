defmodule Agentmancer.Repo.Migrations.CreateWorkflowDefinitions do
  use Ecto.Migration

  def change do
    create table(:workflow_definitions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :enabled, :boolean, default: true
      add :config, :map
      add :archived_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:workflow_definitions, [:project_id, :slug])
  end
end
