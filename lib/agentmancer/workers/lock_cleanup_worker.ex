defmodule Agentmancer.Workers.LockCleanupWorker do
  use Oban.Worker, queue: :maintenance, max_attempts: 1

  import Ecto.Query

  alias Agentmancer.Repo
  alias Agentmancer.Execution.WorkspaceLock

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()

    expired_locks =
      WorkspaceLock
      |> where([l], is_nil(l.released_at))
      |> Repo.all()
      |> Enum.filter(fn lock ->
        expires_at = DateTime.add(lock.locked_at, lock.ttl_seconds, :second)
        DateTime.compare(expires_at, now) == :lt
      end)

    {count, _} =
      if expired_locks != [] do
        ids = Enum.map(expired_locks, & &1.id)

        WorkspaceLock
        |> where([l], l.id in ^ids)
        |> Repo.update_all(set: [released_at: now])
      else
        {0, nil}
      end

    if count > 0 do
      require Logger
      Logger.info("LockCleanupWorker released #{count} expired workspace locks")
    end

    :ok
  end
end
