defmodule Agentmancer.Workflows.WorkflowDefinition do
  use Agentmancer.ProjectScopedSchema

  schema "workflow_definitions" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :enabled, :boolean, default: true
    field :config, :map, default: %{}
    field :archived_at, :utc_datetime_usec

    belongs_to :project, Agentmancer.Projects.Project
    belongs_to :runtime_profile, Agentmancer.RuntimeProfiles.RuntimeProfile

    timestamps()
  end

  def changeset(workflow_definition, attrs) do
    workflow_definition
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :enabled,
      :config,
      :archived_at,
      :project_id,
      :runtime_profile_id
    ])
    |> validate_required([:name, :slug])
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/)
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:runtime_profile_id)
  end
end
