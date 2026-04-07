defmodule Agentmancer.Repo.Migrations.CreateMcpServers do
  use Ecto.Migration

  def change do
    create table(:mcp_servers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :transport, :string, null: false
      add :command, :string
      add :args, {:array, :string}, default: []
      add :url, :string
      add :headers, :map
      add :env_vars, :map
      add :health_check_url, :string

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:mcp_servers, [:project_id, :name])

    create constraint(:mcp_servers, :transport_must_be_valid,
             check: "transport IN ('stdio', 'sse', 'streamable_http')"
           )
  end
end
