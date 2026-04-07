defmodule Agentmancer.Repo.Migrations.CreateRunAttempts do
  use Ecto.Migration

  def change do
    create table(:run_attempts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :run_id, references(:runs, type: :binary_id, on_delete: :restrict), null: false
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false
      add :attempt_number, :integer, null: false
      add :status, :string, null: false
      add :engine, :string, null: false
      add :engine_version, :string
      add :worktree_path, :string
      add :exit_code, :integer
      add :error_class, :string
      add :error_message, :text
      add :token_usage, :map
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :duration_ms, :integer

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:run_attempts, [:run_id, :attempt_number])
    create index(:run_attempts, [:status])
  end
end
