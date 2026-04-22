defmodule Agentmancer.Repo.Migrations.CreateWorkspaceLocks do
  use Ecto.Migration

  def change do
    create table(:workspace_locks, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :restrict),
        null: false

      add :run_attempt_id, references(:run_attempts, type: :binary_id, on_delete: :restrict),
        null: false

      add :worktree_path, :string, null: false
      add :locked_at, :utc_datetime_usec, null: false
      add :released_at, :utc_datetime_usec
      add :ttl_seconds, :integer, default: 3600

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:workspace_locks, [:run_attempt_id])

    create unique_index(:workspace_locks, [:repository_id, :worktree_path],
             where: "released_at IS NULL"
           )
  end
end
