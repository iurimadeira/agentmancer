defmodule Agentmancer.GitHub.FixLoop.BranchLock do
  def acquire(repo_id, branch) do
    key = {:branch_lock, repo_id, branch}

    case Registry.register(Agentmancer.LockRegistry, key, self()) do
      {:ok, _} -> {:ok, key}
      {:error, {:already_registered, _}} -> {:error, :locked}
    end
  end

  def release(repo_id, branch) do
    Registry.unregister(Agentmancer.LockRegistry, {:branch_lock, repo_id, branch})
    :ok
  end

  def locked?(repo_id, branch) do
    Registry.lookup(Agentmancer.LockRegistry, {:branch_lock, repo_id, branch}) != []
  end
end
