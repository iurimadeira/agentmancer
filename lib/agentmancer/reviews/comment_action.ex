defmodule Agentmancer.Reviews.CommentAction do
  use Agentmancer.ProjectScopedSchema

  schema "comment_actions" do
    field :direction, Ecto.Enum, values: [:inbound, :outbound]
    field :github_comment_id, :integer
    field :author, :string
    field :body, :string
    field :action_taken, :string

    belongs_to :project, Agentmancer.Projects.Project
    belongs_to :review_thread, Agentmancer.Reviews.ReviewThread
    belongs_to :run_attempt, Agentmancer.Execution.RunAttempt

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(comment_action, attrs) do
    comment_action
    |> cast(attrs, [
      :direction,
      :github_comment_id,
      :author,
      :body,
      :action_taken,
      :project_id,
      :review_thread_id,
      :run_attempt_id
    ])
    |> validate_required([:direction, :author, :body, :review_thread_id])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:review_thread_id)
    |> foreign_key_constraint(:run_attempt_id)
  end
end
