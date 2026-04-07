defmodule Agentmancer.Workspace.Git do
  require Logger

  alias Agentmancer.Workspace.Paths

  @spec ensure_mirror(String.t(), String.t()) :: :ok | {:error, term()}
  def ensure_mirror(repo_id, clone_url) do
    mirror_path = Paths.mirror_path(repo_id)

    if File.dir?(mirror_path) do
      case System.cmd("git", ["remote", "update"], cd: mirror_path, stderr_to_stdout: true) do
        {_output, 0} -> :ok
        {output, code} -> {:error, {:mirror_update_failed, code, output}}
      end
    else
      File.mkdir_p!(Path.dirname(mirror_path))

      case System.cmd("git", ["clone", "--mirror", clone_url, mirror_path],
             stderr_to_stdout: true
           ) do
        {_output, 0} -> :ok
        {output, code} -> {:error, {:mirror_clone_failed, code, output}}
      end
    end
  end

  @spec create_worktree(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def create_worktree(mirror_path, run_id, ref) do
    worktree_path = Paths.worktree_path(run_id)
    File.mkdir_p!(Path.dirname(worktree_path))

    case System.cmd("git", ["worktree", "add", worktree_path, ref],
           cd: mirror_path,
           stderr_to_stdout: true
         ) do
      {_output, 0} -> {:ok, worktree_path}
      {output, code} -> {:error, {:worktree_create_failed, code, output}}
    end
  end

  @spec remove_worktree(String.t()) :: :ok | {:error, term()}
  def remove_worktree(worktree_path) do
    unless File.dir?(worktree_path) do
      :ok
    else
      parent = Path.dirname(worktree_path)

      case System.cmd("git", ["worktree", "remove", "--force", worktree_path],
             cd: parent,
             stderr_to_stdout: true
           ) do
        {_output, 0} -> :ok
        {output, code} -> {:error, {:worktree_remove_failed, code, output}}
      end
    end
  end

  @spec fast_forward_push(String.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def fast_forward_push(worktree_path, remote, branch) do
    case System.cmd("git", ["push", remote, branch],
           cd: worktree_path,
           stderr_to_stdout: true
         ) do
      {_output, 0} -> :ok
      {output, code} -> {:error, {:push_failed, code, output}}
    end
  end

  @spec current_remote_head(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def current_remote_head(mirror_path, branch) do
    case System.cmd("git", ["ls-remote", "origin", "refs/heads/#{branch}"],
           cd: mirror_path,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        case String.split(String.trim(output), "\t") do
          [sha | _] when byte_size(sha) >= 40 -> {:ok, sha}
          _ -> {:error, {:branch_not_found, branch}}
        end

      {output, code} ->
        {:error, {:ls_remote_failed, code, output}}
    end
  end
end
