defmodule Agentmancer.Agents.AgentVersion do
  use Agentmancer.ProjectScopedSchema

  schema "agent_versions" do
    field :version_number, :integer
    field :system_prompt, :string
    field :input_schema, :map
    field :output_schema, :map
    field :config, :map, default: %{}
    field :change_note, :string
    field :created_by, :string

    belongs_to :project, Agentmancer.Projects.Project
    belongs_to :agent_definition, Agentmancer.Agents.AgentDefinition

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(agent_version, attrs) do
    agent_version
    |> cast(attrs, [
      :version_number,
      :system_prompt,
      :input_schema,
      :output_schema,
      :config,
      :change_note,
      :created_by,
      :project_id,
      :agent_definition_id
    ])
    |> validate_required([:version_number, :system_prompt, :agent_definition_id])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:agent_definition_id)
  end
end
