defmodule Agentmancer.Delivery.Delivery do
  use Agentmancer.ProjectScopedSchema

  schema "deliveries" do
    field :channel, Ecto.Enum, values: [:github_pr_comment, :github_pr_review, :slack, :webhook]
    field :status, Ecto.Enum, values: [:pending, :delivered, :failed], default: :pending
    field :config, :map
    field :payload, :map
    field :response, :map
    field :error_message, :string
    field :attempts, :integer, default: 0
    field :max_attempts, :integer, default: 3
    field :delivered_at, :utc_datetime_usec

    belongs_to :project, Agentmancer.Projects.Project
    belongs_to :run, Agentmancer.Execution.Run

    timestamps()
  end

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, [
      :channel,
      :status,
      :config,
      :payload,
      :response,
      :error_message,
      :attempts,
      :max_attempts,
      :delivered_at,
      :project_id,
      :run_id
    ])
    |> validate_required([:channel, :status, :run_id])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:run_id)
  end
end
