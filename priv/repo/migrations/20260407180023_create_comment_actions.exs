defmodule Agentmancer.Repo.Migrations.CreateCommentActions do
  use Ecto.Migration

  def change do
    create table(:comment_actions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false

      add :review_thread_id, references(:review_threads, type: :binary_id, on_delete: :restrict),
        null: false

      add :run_attempt_id, references(:run_attempts, type: :binary_id, on_delete: :restrict)
      add :direction, :string, null: false
      add :github_comment_id, :bigint
      add :author, :string, null: false
      add :body, :text, null: false
      add :action_taken, :string

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end
  end
end
