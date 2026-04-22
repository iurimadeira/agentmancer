defmodule Agentmancer.Workspace.Paths do
  @spec base_dir() :: String.t()
  def base_dir do
    Application.get_env(:agentmancer, :workspace_base_dir, "var")
  end

  @spec mirror_path(String.t()) :: String.t()
  def mirror_path(repo_id) do
    Path.join([base_dir(), "mirrors", repo_id])
  end

  @spec worktree_path(String.t()) :: String.t()
  def worktree_path(run_id) do
    Path.join([base_dir(), "workspaces", run_id])
  end

  @spec artifact_path(String.t()) :: String.t()
  def artifact_path(run_id) do
    Path.join([base_dir(), "artifacts", run_id])
  end
end
