defmodule Agentmancer.RuntimeProfiles do
  import Ecto.Query

  alias Agentmancer.Repo
  alias Agentmancer.Projects.Project
  alias Agentmancer.RuntimeProfiles.RuntimeProfile
  alias Agentmancer.Workflows.WorkflowDefinition

  def list_runtime_profiles(project_id) do
    RuntimeProfile
    |> where([r], r.project_id == ^project_id)
    |> order_by(:name)
    |> Repo.all()
  end

  def get_runtime_profile!(id), do: Repo.get!(RuntimeProfile, id)

  def create_runtime_profile(attrs) do
    %RuntimeProfile{} |> RuntimeProfile.changeset(attrs) |> Repo.insert()
  end

  def update_runtime_profile(%RuntimeProfile{} = profile, attrs) do
    profile |> RuntimeProfile.changeset(attrs) |> Repo.update()
  end

  def change_runtime_profile(%RuntimeProfile{} = profile, attrs \\ %{}) do
    RuntimeProfile.changeset(profile, attrs)
  end

  def default_runtime_profile(%Project{default_runtime_profile: %RuntimeProfile{} = profile}),
    do: profile

  def default_runtime_profile(%Project{id: project_id}) do
    RuntimeProfile
    |> where([r], r.project_id == ^project_id)
    |> order_by(:inserted_at)
    |> Repo.one()
  end

  def resolve_for_workflow(
        %WorkflowDefinition{runtime_profile: %RuntimeProfile{} = profile},
        _project
      ),
      do: profile

  def resolve_for_workflow(%WorkflowDefinition{}, %Project{} = project) do
    default_runtime_profile(project)
  end
end
