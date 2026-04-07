defmodule Agentmancer.Execution.RunLog do
  use Agentmancer.Schema

  schema "run_logs" do
    field :timestamp, :utc_datetime_usec
    field :level, :string
    field :source, :string
    field :message, :string
    field :metadata, :map
    field :project_id, :binary_id

    belongs_to :run_attempt, Agentmancer.Execution.RunAttempt

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(run_log, attrs) do
    run_log
    |> cast(attrs, [
      :timestamp,
      :level,
      :source,
      :message,
      :metadata,
      :project_id,
      :run_attempt_id
    ])
    |> validate_required([:timestamp, :level, :source, :message, :run_attempt_id])
    |> foreign_key_constraint(:run_attempt_id)
  end
end
