defmodule Agentmancer.Agents.AgentDefinition do
  use Agentmancer.ProjectScopedSchema

  schema "agent_definitions" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :kind, Ecto.Enum, values: [:pr_review, :auto_fix, :ticket_triage, :digest, :custom]
    field :category, :string
    field :template_slug, :string
    field :trigger_type, Ecto.Enum, values: [:schedule, :webhook, :manual]
    field :trigger_config, :map, default: %{}
    field :trigger_enabled, :boolean, default: false
    field :last_triggered_at, :utc_datetime_usec
    field :archived_at, :utc_datetime_usec

    belongs_to :project, Agentmancer.Projects.Project
    belongs_to :runtime_profile, Agentmancer.Agents.RuntimeProfile
    belongs_to :active_version, Agentmancer.Agents.AgentVersion

    has_many :versions, Agentmancer.Agents.AgentVersion, foreign_key: :agent_definition_id

    timestamps()
  end

  def changeset(agent_definition, attrs) do
    agent_definition
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :kind,
      :category,
      :template_slug,
      :trigger_type,
      :trigger_config,
      :trigger_enabled,
      :last_triggered_at,
      :archived_at,
      :project_id,
      :runtime_profile_id,
      :active_version_id
    ])
    |> validate_required([:name, :slug, :kind, :runtime_profile_id])
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/)
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:runtime_profile_id)
    |> foreign_key_constraint(:active_version_id)
  end
end
