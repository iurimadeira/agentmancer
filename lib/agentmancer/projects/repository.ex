defmodule Agentmancer.Projects.Repository do
  use Agentmancer.ProjectScopedSchema

  schema "repositories" do
    field :name, :string
    field :clone_url, :string
    field :default_branch, :string, default: "main"
    field :github_owner, :string
    field :github_repo, :string
    field :mirror_path, :string
    field :last_synced_at, :utc_datetime_usec
    field :settings, :map, default: %{}
    field :archived_at, :utc_datetime_usec

    belongs_to :project, Agentmancer.Projects.Project

    timestamps()
  end

  def changeset(repository, attrs) do
    repository
    |> cast(attrs, [
      :name,
      :clone_url,
      :default_branch,
      :github_owner,
      :github_repo,
      :mirror_path,
      :last_synced_at,
      :settings,
      :archived_at,
      :project_id
    ])
    |> validate_required([:name, :clone_url])
    |> foreign_key_constraint(:project_id)
  end
end
