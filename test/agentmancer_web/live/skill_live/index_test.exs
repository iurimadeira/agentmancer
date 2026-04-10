defmodule AgentmancerWeb.SkillLive.IndexTest do
  use AgentmancerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "renders bundled global skills", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/skills")

    assert has_element?(view, "#global-skills-grid")
    assert has_element?(view, "#global-skill-pr-reviewer")
  end
end
