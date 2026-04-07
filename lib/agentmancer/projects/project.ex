defmodule Agentmancer.Projects.Project do
  use Agentmancer.Schema

  schema "projects" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :settings, :map, default: %{}
    field :archived_at, :utc_datetime_usec

    has_many :repositories, Agentmancer.Projects.Repository
    has_many :agent_definitions, Agentmancer.Agents.AgentDefinition
    has_many :workflow_definitions, Agentmancer.Workflows.WorkflowDefinition

    timestamps()
  end

  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :slug, :description, :settings, :archived_at])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/)
    |> unique_constraint(:slug)
  end
end
