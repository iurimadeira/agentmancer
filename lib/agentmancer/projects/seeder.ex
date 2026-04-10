defmodule Agentmancer.Projects.Seeder do
  alias Agentmancer.Projects
  alias Agentmancer.Repo
  alias Agentmancer.RuntimeProfiles
  alias Agentmancer.Skills
  alias Agentmancer.Workflows

  def seed_defaults(project) do
    Repo.transaction(fn ->
      profiles = seed_runtime_profiles(project)
      seed_default_runtime_profile(project, profiles)
      seed_workflows(project)
    end)

    project
  end

  defp seed_runtime_profiles(project) do
    defaults = [
      %{name: "codex-default", engine: :codex_cli, model: "o3-mini", timeout_seconds: 600},
      %{
        name: "claude-default",
        engine: :claude_code_cli,
        model: "claude-sonnet-4-5-20250514",
        timeout_seconds: 600
      }
    ]

    for attrs <- defaults, into: %{} do
      {:ok, profile} =
        RuntimeProfiles.create_runtime_profile(Map.put(attrs, :project_id, project.id))

      {attrs.name, profile}
    end
  end

  defp seed_default_runtime_profile(project, profiles) do
    default_profile = Map.fetch!(profiles, "claude-default")
    {:ok, _project} = Projects.set_default_runtime_profile(project, default_profile.id)
  end

  defp seed_workflows(project) do
    for skill <- Skills.list_seedable_global_skills() do
      {:ok, workflow} =
        Workflows.create_workflow_definition(%{
          project_id: project.id,
          name: skill.name,
          slug: skill.slug,
          description: skill.description
        })

      seed_suggested_trigger(project, workflow, skill.suggested_trigger)
    end
  end

  defp seed_suggested_trigger(_project, _workflow, trigger) when trigger in [nil, %{}], do: :ok

  defp seed_suggested_trigger(project, workflow, %{"type" => type} = trigger) do
    {:ok, _trigger} =
      Workflows.create_trigger(%{
        project_id: project.id,
        workflow_definition_id: workflow.id,
        type: String.to_existing_atom(type),
        name: Map.get(trigger, "name", "#{workflow.name} Trigger"),
        enabled: false,
        config: Map.get(trigger, "config", %{})
      })
  end
end
