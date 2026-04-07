defmodule Agentmancer.Repo.Migrations.CreateRunEnvSnapshots do
  use Ecto.Migration

  def change do
    create table(:run_env_snapshots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :run_id, references(:runs, type: :binary_id, on_delete: :restrict), null: false
      add :env_ciphertext, :binary, null: false
      add :scope_chain, :map

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:run_env_snapshots, [:run_id])
  end
end
