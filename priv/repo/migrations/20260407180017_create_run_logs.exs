defmodule Agentmancer.Repo.Migrations.CreateRunLogs do
  use Ecto.Migration

  def change do
    create table(:run_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :run_attempt_id, references(:run_attempts, type: :binary_id, on_delete: :restrict),
        null: false

      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false
      add :timestamp, :utc_datetime_usec, null: false
      add :level, :string, null: false
      add :source, :string, null: false
      add :message, :text, null: false
      add :metadata, :map

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:run_logs, [:run_attempt_id, :timestamp])
  end
end
