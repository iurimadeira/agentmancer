defmodule Agentmancer.Repo.Migrations.CreateVariableScopesAndVariables do
  use Ecto.Migration

  def change do
    create table(:variable_scopes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :level, :string, null: false
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict)
      add :repository_id, references(:repositories, type: :binary_id, on_delete: :restrict)

      add :workflow_definition_id,
          references(:workflow_definitions, type: :binary_id, on_delete: :restrict)

      add :run_id, :binary_id

      timestamps(type: :utc_datetime_usec)
    end

    create constraint(:variable_scopes, :level_must_be_valid,
             check: "level IN ('global', 'project', 'repository', 'workflow', 'run_override')"
           )

    create table(:variables, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :variable_scope_id,
          references(:variable_scopes, type: :binary_id, on_delete: :restrict), null: false

      add :key, :string, null: false
      add :value_ciphertext, :binary, null: false
      add :is_secret, :boolean, default: false
      add :description, :string

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:variables, [:variable_scope_id, :key])
  end
end
