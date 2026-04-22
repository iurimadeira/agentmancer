defmodule Agentmancer.Reviews.Finding do
  use Agentmancer.ProjectScopedSchema

  schema "findings" do
    field :file_path, :string
    field :line_start, :integer
    field :line_end, :integer
    field :severity, Ecto.Enum, values: [:info, :warning, :error, :critical]
    field :category, :string
    field :title, :string
    field :body, :string
    field :suggested_fix, :string
    field :commit_sha, :string
    field :status, Ecto.Enum, values: [:open, :resolved, :dismissed, :wont_fix], default: :open
    field :github_comment_id, :integer
    field :metadata, :map

    belongs_to :run_attempt, Agentmancer.Execution.RunAttempt
    belongs_to :project, Agentmancer.Projects.Project
    belongs_to :repository, Agentmancer.Projects.Repository

    timestamps()
  end

  def changeset(finding, attrs) do
    finding
    |> cast(attrs, [
      :file_path,
      :line_start,
      :line_end,
      :severity,
      :category,
      :title,
      :body,
      :suggested_fix,
      :commit_sha,
      :status,
      :github_comment_id,
      :metadata,
      :run_attempt_id,
      :project_id,
      :repository_id
    ])
    |> validate_required([
      :file_path,
      :severity,
      :category,
      :title,
      :body,
      :commit_sha,
      :run_attempt_id,
      :repository_id
    ])
    |> foreign_key_constraint(:run_attempt_id)
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:repository_id)
  end
end
