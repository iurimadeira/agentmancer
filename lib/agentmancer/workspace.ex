defmodule Agentmancer.Workspace do
  require Logger

  alias Agentmancer.Workspace.{Git, Materializer, Paths}

  @type setup_spec :: %{
          run_id: String.t(),
          repo_id: String.t(),
          clone_url: String.t(),
          ref: String.t(),
          head_sha: String.t() | nil
        }

  @type workspace_context :: %{
          worktree_path: String.t(),
          mirror_path: String.t(),
          ref: String.t(),
          head_sha: String.t() | nil
        }

  @spec setup(setup_spec()) :: {:ok, workspace_context()} | {:error, term()}
  def setup(spec) do
    mirror_path = Paths.mirror_path(spec.repo_id)
    worktree_path = Paths.worktree_path(spec.run_id)

    with :ok <- Git.ensure_mirror(spec.repo_id, spec.clone_url),
         {:ok, _} <- Git.create_worktree(mirror_path, spec.run_id, spec.ref) do
      {:ok,
       %{
         worktree_path: worktree_path,
         mirror_path: mirror_path,
         ref: spec.ref,
         head_sha: spec.head_sha
       }}
    else
      {:error, reason} = err ->
        Logger.error("Workspace setup failed for run #{spec.run_id}: #{inspect(reason)}")
        cleanup(spec.run_id, worktree_path)
        err
    end
  end

  @spec materialize(String.t(), Materializer.config()) :: :ok | {:error, term()}
  def materialize(worktree_path, config) do
    Materializer.materialize(worktree_path, config)
  end

  @spec cleanup(String.t(), String.t()) :: :ok
  def cleanup(run_id, worktree_path) do
    case Git.remove_worktree(worktree_path) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Failed to remove worktree for run #{run_id} at #{worktree_path}: #{inspect(reason)}"
        )

        :ok
    end
  end
end
