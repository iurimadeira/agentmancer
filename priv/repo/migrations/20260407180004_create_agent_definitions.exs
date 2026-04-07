defmodule Agentmancer.Repo.Migrations.CreateAgentDefinitions do
  use Ecto.Migration

  def change do
    create table(:agent_definitions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :kind, :string, null: false

      add :runtime_profile_id,
          references(:runtime_profiles, type: :binary_id, on_delete: :restrict)

      add :active_version_id, :binary_id
      add :archived_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:agent_definitions, [:project_id, :slug])

    create constraint(:agent_definitions, :kind_must_be_valid,
             check: "kind IN ('pr_review', 'auto_fix', 'ticket_triage', 'digest', 'custom')"
           )
  end
end
