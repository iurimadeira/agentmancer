defmodule Agentmancer.Projects do
  import Ecto.Query
  alias Agentmancer.Repo
  alias Agentmancer.Projects.{Project, Repository}
  alias Agentmancer.RuntimeProfiles

  # Project CRUD

  def list_active_projects do
    Project
    |> where([p], is_nil(p.archived_at))
    |> order_by(:name)
    |> Repo.all()
    |> Repo.preload(:default_runtime_profile)
  end

  def get_project!(id), do: Repo.get!(Project, id)

  def get_project_by_slug!(slug) do
    Project
    |> Repo.get_by!(slug: slug)
    |> Repo.preload(:default_runtime_profile)
  end

  def create_project(attrs) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, project} ->
        Agentmancer.Projects.Seeder.seed_defaults(project)
        {:ok, project}

      error ->
        error
    end
  end

  def update_project(%Project{} = project, attrs) do
    project |> Project.changeset(attrs) |> Repo.update()
  end

  def archive_project(%Project{} = project) do
    project |> Project.changeset(%{archived_at: DateTime.utc_now()}) |> Repo.update()
  end

  def set_default_runtime_profile(%Project{} = project, runtime_profile_id) do
    project
    |> Project.changeset(%{default_runtime_profile_id: runtime_profile_id})
    |> Repo.update()
  end

  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end

  # Repository CRUD

  def list_repositories(project_id) do
    Repository
    |> where([r], r.project_id == ^project_id and is_nil(r.archived_at))
    |> order_by(:name)
    |> Repo.all()
  end

  def get_repository!(id), do: Repo.get!(Repository, id)

  def create_repository(attrs) do
    %Repository{} |> Repository.changeset(attrs) |> Repo.insert()
  end

  def update_repository(%Repository{} = repo, attrs) do
    repo |> Repository.changeset(attrs) |> Repo.update()
  end

  def change_repository(%Repository{} = repo, attrs \\ %{}) do
    Repository.changeset(repo, attrs)
  end

  def default_runtime_profile(%Project{} = project) do
    RuntimeProfiles.default_runtime_profile(project)
  end
end
