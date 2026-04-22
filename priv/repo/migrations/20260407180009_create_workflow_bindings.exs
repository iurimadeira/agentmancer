defmodule Agentmancer.Repo.Migrations.CreateWorkflowBindings do
  use Ecto.Migration

  def change do
    create table(:workflow_bindings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false

      add :workflow_definition_id,
          references(:workflow_definitions, type: :binary_id, on_delete: :restrict), null: false

      add :agent_definition_id,
          references(:agent_definitions, type: :binary_id, on_delete: :restrict), null: false

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :restrict)
      add :position, :integer
      add :config, :map
      add :enabled, :boolean, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:workflow_bindings, [
             :workflow_definition_id,
             :agent_definition_id,
             :repository_id
           ])
  end
end
