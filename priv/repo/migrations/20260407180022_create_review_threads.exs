defmodule Agentmancer.Repo.Migrations.CreateReviewThreads do
  use Ecto.Migration

  def change do
    create table(:review_threads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :restrict),
        null: false

      add :pr_number, :integer, null: false
      add :github_thread_id, :bigint
      add :github_comment_id, :bigint
      add :file_path, :string, null: false
      add :line_number, :integer
      add :status, :string, null: false
      add :last_actor, :string, null: false
      add :finding_id, references(:findings, type: :binary_id, on_delete: :restrict)
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:review_threads, [:repository_id, :pr_number, :github_thread_id])
    create index(:review_threads, [:repository_id, :pr_number])
  end
end
