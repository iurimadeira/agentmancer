defmodule Agentmancer.Execution.WorkspaceLock do
  use Agentmancer.Schema

  schema "workspace_locks" do
    field :worktree_path, :string
    field :locked_at, :utc_datetime_usec
    field :released_at, :utc_datetime_usec
    field :ttl_seconds, :integer, default: 3600

    belongs_to :repository, Agentmancer.Projects.Repository
    belongs_to :run_attempt, Agentmancer.Execution.RunAttempt

    timestamps()
  end

  def changeset(workspace_lock, attrs) do
    workspace_lock
    |> cast(attrs, [
      :worktree_path,
      :locked_at,
      :released_at,
      :ttl_seconds,
      :repository_id,
      :run_attempt_id
    ])
    |> validate_required([:worktree_path, :locked_at, :repository_id, :run_attempt_id])
    |> foreign_key_constraint(:repository_id)
    |> foreign_key_constraint(:run_attempt_id)
    |> unique_constraint(:run_attempt_id)
    |> unique_constraint([:repository_id, :worktree_path])
  end
end
