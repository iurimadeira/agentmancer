defmodule AgentmancerWeb.WorkflowLive.ShowTest do
  use AgentmancerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Agentmancer.Projects
  alias Agentmancer.Workflows

  setup :register_and_log_in_user

  test "renders workflow skill and runtime forms", %{conn: conn} do
    slug = "project-#{System.unique_integer([:positive])}"
    {:ok, project} = Projects.create_project(%{name: "Project", slug: slug})

    workflow =
      Enum.find(Workflows.list_workflow_definitions(project.id), &(&1.slug == "pr-reviewer"))

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.slug}/workflows/#{workflow.slug}")

    assert has_element?(view, "#workflow-binding-form")
    assert has_element?(view, "#workflow-binding-form select[name='binding[skill_source]']")
    assert has_element?(view, "#workflow-runtime-form")

    assert has_element?(
             view,
             "#workflow-runtime-form select[name='workflow_runtime[runtime_profile_id]']"
           )
  end
end
