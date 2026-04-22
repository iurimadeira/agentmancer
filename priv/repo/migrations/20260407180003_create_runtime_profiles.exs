defmodule Agentmancer.Repo.Migrations.CreateRuntimeProfiles do
  use Ecto.Migration

  def change do
    create table(:runtime_profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :engine, :string, null: false
      add :model, :string
      add :timeout_seconds, :integer, default: 600
      add :max_tokens, :integer
      add :config, :map

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:runtime_profiles, [:project_id, :name])

    create constraint(:runtime_profiles, :engine_must_be_valid,
             check: "engine IN ('codex_cli', 'claude_code_cli')"
           )
  end
end
