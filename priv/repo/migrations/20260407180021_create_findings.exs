defmodule Agentmancer.Repo.Migrations.CreateFindings do
  use Ecto.Migration

  def change do
    create table(:findings, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :run_attempt_id, references(:run_attempts, type: :binary_id, on_delete: :restrict),
        null: false

      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :restrict),
        null: false

      add :file_path, :string, null: false
      add :line_start, :integer
      add :line_end, :integer
      add :severity, :string, null: false
      add :category, :string, null: false
      add :title, :string, null: false
      add :body, :text, null: false
      add :suggested_fix, :text
      add :commit_sha, :string, null: false
      add :status, :string, null: false, default: "open"
      add :github_comment_id, :bigint
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:findings, [:run_attempt_id])
    create index(:findings, [:repository_id, :file_path])
  end
end
