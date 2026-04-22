defmodule Agentmancer.SkillsTest do
  use Agentmancer.DataCase, async: true

  alias Agentmancer.Skills

  test "lists bundled global skills" do
    skills = Skills.list_global_skills()
    reviewer = Enum.find(skills, &(&1.slug == "pr-reviewer"))

    assert reviewer
    assert reviewer.source == :global
    assert reviewer.body != ""
    assert reviewer.seed_default_workflow == true
    assert reviewer.suggested_trigger["type"] == "webhook"
  end

  test "returns not found for a missing global skill" do
    assert {:error, :not_found} = Skills.fetch_global_skill("missing-skill")
  end
end
