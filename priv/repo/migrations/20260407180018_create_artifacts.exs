defmodule Agentmancer.Repo.Migrations.CreateArtifacts do
  use Ecto.Migration

  def change do
    create table(:artifacts, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :run_attempt_id, references(:run_attempts, type: :binary_id, on_delete: :restrict),
        null: false

      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :kind, :string, null: false
      add :content_type, :string, null: false
      add :size_bytes, :bigint, null: false
      add :storage_backend, :string, null: false
      add :storage_path, :string, null: false
      add :checksum_sha256, :string, null: false
      add :metadata, :map

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:artifacts, [:run_attempt_id])
  end
end
