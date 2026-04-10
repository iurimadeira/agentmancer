defmodule AgentmancerWeb.ProjectSkillLive.IndexTest do
  use AgentmancerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Agentmancer.Projects

  setup :register_and_log_in_user

  test "renders global skills for a project without repositories", %{conn: conn} do
    slug = "project-#{System.unique_integer([:positive])}"
    {:ok, project} = Projects.create_project(%{name: "Project", slug: slug})

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.slug}/skills")

    assert has_element?(view, "#project-global-skills")
    assert has_element?(view, "#project-global-skill-pr-reviewer")
  end
end
