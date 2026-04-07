defmodule Agentmancer.Agents.McpServer do
  use Agentmancer.ProjectScopedSchema

  schema "mcp_servers" do
    field :name, :string
    field :transport, Ecto.Enum, values: [:stdio, :sse, :streamable_http]
    field :command, :string
    field :args, {:array, :string}, default: []
    field :url, :string
    field :headers, :map, default: %{}
    field :env_vars, :map, default: %{}
    field :health_check_url, :string

    belongs_to :project, Agentmancer.Projects.Project

    timestamps()
  end

  def changeset(mcp_server, attrs) do
    mcp_server
    |> cast(attrs, [
      :name,
      :transport,
      :command,
      :args,
      :url,
      :headers,
      :env_vars,
      :health_check_url,
      :project_id
    ])
    |> validate_required([:name, :transport])
    |> foreign_key_constraint(:project_id)
  end
end
