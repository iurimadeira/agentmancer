defmodule Agentmancer.Repo.Migrations.CreateAgentVersions do
  use Ecto.Migration

  def change do
    create table(:agent_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false

      add :agent_definition_id,
          references(:agent_definitions, type: :binary_id, on_delete: :restrict), null: false

      add :version_number, :integer, null: false
      add :system_prompt, :text, null: false
      add :input_schema, :map
      add :output_schema, :map
      add :config, :map
      add :change_note, :text
      add :created_by, :string

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:agent_versions, [:agent_definition_id, :version_number])

    alter table(:agent_definitions) do
      modify :active_version_id,
             references(:agent_versions, type: :binary_id, on_delete: :nilify_all),
             from: :binary_id
    end
  end
end
