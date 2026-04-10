defmodule Agentmancer.Skills.Skill do
  @enforce_keys [:source, :slug, :name, :body]
  defstruct [
    :source,
    :slug,
    :name,
    :description,
    :kind,
    :icon,
    :body,
    :path,
    :repository_id,
    :repository_name,
    tags: [],
    output_schema: nil,
    suggested_trigger: %{},
    seed_default_workflow: false,
    metadata: %{}
  ]
end
