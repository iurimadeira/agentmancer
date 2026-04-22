defmodule Agentmancer.Reviews.ReviewThread do
  use Agentmancer.ProjectScopedSchema

  schema "review_threads" do
    field :pr_number, :integer
    field :github_thread_id, :integer
    field :github_comment_id, :integer
    field :file_path, :string
    field :line_number, :integer
    field :status, Ecto.Enum, values: [:open, :resolved, :outdated]
    field :last_actor, :string
    field :metadata, :map

    belongs_to :project, Agentmancer.Projects.Project
    belongs_to :repository, Agentmancer.Projects.Repository
    belongs_to :finding, Agentmancer.Reviews.Finding

    timestamps()
  end

  def changeset(review_thread, attrs) do
    review_thread
    |> cast(attrs, [
      :pr_number,
      :github_thread_id,
      :github_comment_id,
      :file_path,
      :line_number,
      :status,
      :last_actor,
      :metadata,
      :project_id,
      :repository_id,
      :finding_id
    ])
    |> validate_required([:pr_number, :file_path, :status, :last_actor, :repository_id])
    |> unique_constraint([:repository_id, :pr_number, :github_thread_id])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:repository_id)
    |> foreign_key_constraint(:finding_id)
  end
end
