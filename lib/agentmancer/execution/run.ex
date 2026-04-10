defmodule Agentmancer.Execution.Run do
  use Agentmancer.ProjectScopedSchema

  schema "runs" do
    field :status, Ecto.Enum,
      values: [:pending, :preparing, :running, :success, :failure, :cancelled, :timed_out, :stale],
      default: :pending

    field :number, :integer
    field :input, :map
    field :output, :map
    field :pr_number, :integer
    field :pr_head_sha, :string
    field :branch, :string
    field :base_branch, :string
    field :iteration, :integer, default: 1
    field :max_iterations, :integer, default: 3
    field :max_attempts, :integer, default: 1
    field :current_attempt, :integer, default: 0
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
    field :cancelled_at, :utc_datetime_usec
    field :cancelled_by, :string
    field :error_message, :string
    field :oban_job_id, :integer
    field :trigger_event_id, :binary_id
    field :skill_source, Ecto.Enum, values: [:global, :repository]
    field :skill_slug, :string
    field :skill_name, :string
    field :skill_body, :string
    field :skill_metadata, :map, default: %{}

    belongs_to :project, Agentmancer.Projects.Project
    belongs_to :workflow_definition, Agentmancer.Workflows.WorkflowDefinition
    belongs_to :workflow_binding, Agentmancer.Workflows.WorkflowBinding
    belongs_to :repository, Agentmancer.Projects.Repository
    belongs_to :trigger, Agentmancer.Workflows.Trigger
    belongs_to :parent_run, Agentmancer.Execution.Run
    belongs_to :retry_of_run, Agentmancer.Execution.Run

    has_many :attempts, Agentmancer.Execution.RunAttempt, foreign_key: :run_id

    timestamps()
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :status,
      :number,
      :input,
      :output,
      :pr_number,
      :pr_head_sha,
      :branch,
      :base_branch,
      :iteration,
      :max_iterations,
      :max_attempts,
      :current_attempt,
      :started_at,
      :completed_at,
      :cancelled_at,
      :cancelled_by,
      :error_message,
      :oban_job_id,
      :trigger_event_id,
      :skill_source,
      :skill_slug,
      :skill_name,
      :skill_body,
      :skill_metadata,
      :project_id,
      :workflow_definition_id,
      :workflow_binding_id,
      :repository_id,
      :trigger_id,
      :parent_run_id,
      :retry_of_run_id
    ])
    |> validate_required([
      :status,
      :number,
      :project_id,
      :workflow_definition_id,
      :skill_source,
      :skill_slug,
      :repository_id,
      :trigger_id
    ])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:workflow_definition_id)
    |> foreign_key_constraint(:workflow_binding_id)
    |> foreign_key_constraint(:repository_id)
    |> foreign_key_constraint(:trigger_id)
    |> foreign_key_constraint(:parent_run_id)
    |> foreign_key_constraint(:retry_of_run_id)
  end
end
