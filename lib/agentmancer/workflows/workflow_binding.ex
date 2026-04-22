defmodule Agentmancer.Workflows.WorkflowBinding do
  use Agentmancer.ProjectScopedSchema

  schema "workflow_bindings" do
    field :position, :integer
    field :skill_source, Ecto.Enum, values: [:global, :repository]
    field :skill_slug, :string
    field :config, :map, default: %{}
    field :enabled, :boolean, default: true

    belongs_to :project, Agentmancer.Projects.Project
    belongs_to :workflow_definition, Agentmancer.Workflows.WorkflowDefinition
    belongs_to :repository, Agentmancer.Projects.Repository

    timestamps()
  end

  def changeset(workflow_binding, attrs) do
    workflow_binding
    |> cast(attrs, [
      :position,
      :skill_source,
      :skill_slug,
      :config,
      :enabled,
      :project_id,
      :workflow_definition_id,
      :repository_id
    ])
    |> validate_required([
      :workflow_definition_id,
      :position,
      :skill_source,
      :skill_slug,
      :repository_id
    ])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:workflow_definition_id)
    |> foreign_key_constraint(:repository_id)
  end
end
