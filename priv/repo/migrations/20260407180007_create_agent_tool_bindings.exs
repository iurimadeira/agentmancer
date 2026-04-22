defmodule Agentmancer.Repo.Migrations.CreateAgentToolBindings do
  use Ecto.Migration

  def change do
    create table(:agent_tool_bindings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false

      add :agent_definition_id,
          references(:agent_definitions, type: :binary_id, on_delete: :restrict), null: false

      add :mcp_server_id, references(:mcp_servers, type: :binary_id, on_delete: :restrict),
        null: false

      add :tool_filter, {:array, :string}
      add :enabled, :boolean, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:agent_tool_bindings, [:agent_definition_id, :mcp_server_id])
  end
end
