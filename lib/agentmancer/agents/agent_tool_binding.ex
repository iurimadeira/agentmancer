defmodule Agentmancer.Agents.AgentToolBinding do
  use Agentmancer.ProjectScopedSchema

  schema "agent_tool_bindings" do
    field :tool_filter, {:array, :string}
    field :enabled, :boolean, default: true

    belongs_to :project, Agentmancer.Projects.Project
    belongs_to :agent_definition, Agentmancer.Agents.AgentDefinition
    belongs_to :mcp_server, Agentmancer.Agents.McpServer

    timestamps()
  end

  def changeset(agent_tool_binding, attrs) do
    agent_tool_binding
    |> cast(attrs, [:tool_filter, :enabled, :project_id, :agent_definition_id, :mcp_server_id])
    |> validate_required([:agent_definition_id, :mcp_server_id])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:agent_definition_id)
    |> foreign_key_constraint(:mcp_server_id)
  end
end
