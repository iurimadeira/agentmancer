defmodule Agentmancer.Execution.RunAttempt do
  use Agentmancer.ProjectScopedSchema

  schema "run_attempts" do
    field :attempt_number, :integer
    field :status, Ecto.Enum, values: [:running, :success, :failure, :cancelled]
    field :engine, :string
    field :engine_version, :string
    field :worktree_path, :string
    field :exit_code, :integer
    field :error_class, :string
    field :error_message, :string
    field :token_usage, :map
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
    field :duration_ms, :integer

    belongs_to :run, Agentmancer.Execution.Run
    belongs_to :project, Agentmancer.Projects.Project

    timestamps()
  end

  def changeset(run_attempt, attrs) do
    run_attempt
    |> cast(attrs, [
      :attempt_number,
      :status,
      :engine,
      :engine_version,
      :worktree_path,
      :exit_code,
      :error_class,
      :error_message,
      :token_usage,
      :started_at,
      :completed_at,
      :duration_ms,
      :run_id,
      :project_id
    ])
    |> validate_required([:attempt_number, :status, :engine, :run_id])
    |> foreign_key_constraint(:run_id)
    |> foreign_key_constraint(:project_id)
  end
end
