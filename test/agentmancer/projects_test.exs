defmodule Agentmancer.ProjectsTest do
  use Agentmancer.DataCase, async: true

  alias Agentmancer.Projects
  alias Agentmancer.RuntimeProfiles
  alias Agentmancer.Skills
  alias Agentmancer.Workflows

  test "project creation seeds runtime defaults and bundled workflows" do
    slug = "project-#{System.unique_integer([:positive])}"
    {:ok, project} = Projects.create_project(%{name: "Project", slug: slug})

    project = Projects.get_project_by_slug!(project.slug)
    runtime_profiles = RuntimeProfiles.list_runtime_profiles(project.id)
    workflows = Workflows.list_workflow_definitions(project.id)

    assert Enum.map(runtime_profiles, & &1.name) == ["claude-default", "codex-default"]
    assert project.default_runtime_profile.name == "claude-default"

    assert Enum.sort(Enum.map(workflows, & &1.slug)) ==
             Skills.list_seedable_global_skills()
             |> Enum.map(& &1.slug)
             |> Enum.sort()

    assert Enum.all?(workflows, fn workflow ->
             Workflows.list_workflow_bindings(workflow.id) == [] and
               Workflows.list_triggers(workflow.id) != []
           end)
  end
end
