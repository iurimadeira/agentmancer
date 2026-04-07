defmodule Agentmancer.Workers.GitMirrorSyncWorker do
  use Oban.Worker, queue: :maintenance, max_attempts: 1

  require Logger

  import Ecto.Query

  alias Agentmancer.Repo
  alias Agentmancer.Projects.Repository
  alias Agentmancer.Workspace.Git

  @impl Oban.Worker
  def perform(_job) do
    repositories =
      Repository
      |> where([r], is_nil(r.archived_at))
      |> Repo.all()

    for repo <- repositories do
      case Git.ensure_mirror(repo.id, repo.clone_url) do
        :ok ->
          repo
          |> Repository.changeset(%{last_synced_at: DateTime.utc_now()})
          |> Repo.update()

        {:error, reason} ->
          Logger.warning("GitMirrorSyncWorker failed for repo #{repo.id}: #{inspect(reason)}")
      end
    end

    :ok
  end
end
