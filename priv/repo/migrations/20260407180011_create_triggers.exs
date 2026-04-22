defmodule Agentmancer.Repo.Migrations.CreateTriggers do
  use Ecto.Migration

  def change do
    create table(:triggers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false

      add :workflow_definition_id,
          references(:workflow_definitions, type: :binary_id, on_delete: :restrict), null: false

      add :type, :string, null: false
      add :name, :string, null: false
      add :enabled, :boolean, default: true
      add :config, :map
      add :last_triggered_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create constraint(:triggers, :type_must_be_valid,
             check: "type IN ('schedule', 'webhook', 'manual')"
           )
  end
end
