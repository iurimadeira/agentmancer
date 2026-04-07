defmodule Agentmancer.Repo.Migrations.CreateRuns do
  use Ecto.Migration

  def change do
    create table(:runs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false

      add :workflow_definition_id,
          references(:workflow_definitions, type: :binary_id, on_delete: :restrict)

      add :workflow_binding_id,
          references(:workflow_bindings, type: :binary_id, on_delete: :restrict)

      add :agent_definition_id,
          references(:agent_definitions, type: :binary_id, on_delete: :restrict), null: false

      add :agent_version_id, references(:agent_versions, type: :binary_id, on_delete: :restrict)
      add :repository_id, references(:repositories, type: :binary_id, on_delete: :restrict)
      add :trigger_id, references(:triggers, type: :binary_id, on_delete: :restrict)
      add :trigger_event_id, :binary_id
      add :status, :string, null: false, default: "pending"
      add :number, :integer, null: false
      add :input, :map
      add :output, :map
      add :pr_number, :integer
      add :pr_head_sha, :string
      add :branch, :string
      add :base_branch, :string
      add :iteration, :integer, default: 1
      add :max_iterations, :integer, default: 3
      add :parent_run_id, references(:runs, type: :binary_id, on_delete: :restrict)
      add :retry_of_run_id, references(:runs, type: :binary_id, on_delete: :restrict)
      add :max_attempts, :integer, default: 1
      add :current_attempt, :integer, default: 0
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :cancelled_at, :utc_datetime_usec
      add :cancelled_by, :string
      add :error_message, :text
      add :oban_job_id, :bigint

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:runs, [:project_id, :number])
    create index(:runs, [:status])
    create index(:runs, [:repository_id, :pr_number])

    create constraint(:runs, :status_must_be_valid,
             check:
               "status IN ('pending', 'preparing', 'running', 'success', 'failure', 'cancelled', 'timed_out', 'stale')"
           )
  end
end
