defmodule Agentmancer.Agents do
  import Ecto.Query
  alias Agentmancer.Repo

  alias Agentmancer.Agents.{
    AgentDefinition,
    AgentVersion,
    RuntimeProfile,
    McpServer,
    AgentToolBinding
  }

  # Agent Definitions

  def list_agent_definitions(project_id) do
    AgentDefinition
    |> where([a], a.project_id == ^project_id and is_nil(a.archived_at))
    |> order_by(:name)
    |> Repo.all()
  end

  def get_agent_definition!(id), do: Repo.get!(AgentDefinition, id)

  def get_agent_definition_by_slug!(slug), do: Repo.get_by!(AgentDefinition, slug: slug)

  def create_agent_definition(attrs) do
    %AgentDefinition{} |> AgentDefinition.changeset(attrs) |> Repo.insert()
  end

  def update_agent_definition(%AgentDefinition{} = agent_def, attrs) do
    agent_def |> AgentDefinition.changeset(attrs) |> Repo.update()
  end

  def change_agent_definition(%AgentDefinition{} = agent_def, attrs \\ %{}) do
    AgentDefinition.changeset(agent_def, attrs)
  end

  def list_scheduled_agents do
    AgentDefinition
    |> where([a], a.trigger_type == :schedule and a.trigger_enabled == true)
    |> where([a], is_nil(a.archived_at))
    |> where([a], not is_nil(a.active_version_id))
    |> Repo.all()
  end

  def update_last_triggered_at(%AgentDefinition{} = agent) do
    agent
    |> Ecto.Changeset.change(last_triggered_at: DateTime.utc_now())
    |> Repo.update()
  end

  # Agent Versions

  def create_version(%AgentDefinition{} = agent_def, attrs) do
    next_number =
      AgentVersion
      |> where([v], v.agent_definition_id == ^agent_def.id)
      |> select([v], coalesce(max(v.version_number), 0) + 1)
      |> Repo.one()

    version_attrs =
      attrs
      |> Map.put(:version_number, next_number)
      |> Map.put(:agent_definition_id, agent_def.id)
      |> Map.put(:project_id, agent_def.project_id)

    set_active = Map.get(attrs, :set_active, Map.get(attrs, "set_active", false))

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:version, AgentVersion.changeset(%AgentVersion{}, version_attrs))
    |> Ecto.Multi.run(:maybe_set_active, fn repo, %{version: version} ->
      if set_active do
        agent_def
        |> AgentDefinition.changeset(%{active_version_id: version.id})
        |> repo.update()
      else
        {:ok, agent_def}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{version: version}} -> {:ok, version}
      {:error, _step, changeset, _changes} -> {:error, changeset}
    end
  end

  def list_versions(agent_definition_id) do
    AgentVersion
    |> where([v], v.agent_definition_id == ^agent_definition_id)
    |> order_by(desc: :version_number)
    |> Repo.all()
  end

  def get_version!(id), do: Repo.get!(AgentVersion, id)

  # Runtime Profiles

  def list_runtime_profiles(project_id) do
    RuntimeProfile
    |> where([r], r.project_id == ^project_id)
    |> order_by(:name)
    |> Repo.all()
  end

  def get_runtime_profile!(id), do: Repo.get!(RuntimeProfile, id)

  def create_runtime_profile(attrs) do
    %RuntimeProfile{} |> RuntimeProfile.changeset(attrs) |> Repo.insert()
  end

  def update_runtime_profile(%RuntimeProfile{} = profile, attrs) do
    profile |> RuntimeProfile.changeset(attrs) |> Repo.update()
  end

  def change_runtime_profile(%RuntimeProfile{} = profile, attrs \\ %{}) do
    RuntimeProfile.changeset(profile, attrs)
  end

  # MCP Servers

  def list_mcp_servers(project_id) do
    McpServer
    |> where([m], m.project_id == ^project_id)
    |> order_by(:name)
    |> Repo.all()
  end

  def get_mcp_server!(id), do: Repo.get!(McpServer, id)

  def create_mcp_server(attrs) do
    %McpServer{} |> McpServer.changeset(attrs) |> Repo.insert()
  end

  def update_mcp_server(%McpServer{} = server, attrs) do
    server |> McpServer.changeset(attrs) |> Repo.update()
  end

  # Agent Tool Bindings

  def create_agent_tool_binding(attrs) do
    %AgentToolBinding{} |> AgentToolBinding.changeset(attrs) |> Repo.insert()
  end

  def delete_agent_tool_binding(%AgentToolBinding{} = binding) do
    Repo.delete(binding)
  end
end
