defmodule Agentmancer.Workflows.Trigger do
  use Agentmancer.ProjectScopedSchema

  schema "triggers" do
    field :type, Ecto.Enum, values: [:schedule, :webhook, :manual]
    field :name, :string
    field :enabled, :boolean, default: true
    field :config, :map, default: %{}
    field :last_triggered_at, :utc_datetime_usec

    belongs_to :project, Agentmancer.Projects.Project
    belongs_to :workflow_definition, Agentmancer.Workflows.WorkflowDefinition

    timestamps()
  end

  def changeset(trigger, attrs) do
    trigger
    |> cast(attrs, [
      :type,
      :name,
      :enabled,
      :config,
      :last_triggered_at,
      :project_id,
      :workflow_definition_id
    ])
    |> validate_required([:type, :name, :workflow_definition_id])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:workflow_definition_id)
  end
end
