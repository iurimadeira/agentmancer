defmodule Agentmancer.Workers.StaleRunWorker do
  use Oban.Worker, queue: :maintenance, max_attempts: 1

  import Ecto.Query

  alias Agentmancer.Repo
  alias Agentmancer.Execution.Run

  @stale_threshold_minutes 120

  @impl Oban.Worker
  def perform(_job) do
    cutoff = DateTime.add(DateTime.utc_now(), -@stale_threshold_minutes, :minute)

    {count, _} =
      Run
      |> where([r], r.status in [:running, :preparing] and r.started_at < ^cutoff)
      |> Repo.update_all(set: [status: :stale, error_message: "Marked stale by maintenance"])

    if count > 0 do
      require Logger
      Logger.info("StaleRunWorker marked #{count} runs as stale")
    end

    :ok
  end
end
