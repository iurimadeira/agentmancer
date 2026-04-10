defmodule Agentmancer.RuntimeProfiles.RuntimeProfile do
  use Agentmancer.ProjectScopedSchema

  schema "runtime_profiles" do
    field :name, :string
    field :engine, Ecto.Enum, values: [:codex_cli, :claude_code_cli]
    field :model, :string
    field :timeout_seconds, :integer, default: 600
    field :max_tokens, :integer
    field :config, :map, default: %{}

    belongs_to :project, Agentmancer.Projects.Project

    timestamps()
  end

  def changeset(runtime_profile, attrs) do
    runtime_profile
    |> cast(attrs, [:name, :engine, :model, :timeout_seconds, :max_tokens, :config, :project_id])
    |> validate_required([:name, :engine, :model])
    |> foreign_key_constraint(:project_id)
  end
end
