defmodule Agentmancer.Workers.RunExecutionWorker do
  use Oban.Worker, queue: :runs, max_attempts: 1, unique: [fields: [:args], keys: [:run_id]]

  require Logger

  alias Agentmancer.{Execution, Vault}
  alias Agentmancer.Runtime.RunServer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"run_id" => run_id}}) do
    run = Execution.get_run_with_associations!(run_id)

    env =
      Vault.resolve_env(
        project_id: run.project_id,
        repository_id: run.repository_id,
        workflow_definition_id: run.workflow_definition_id
      )

    Vault.create_run_env_snapshot(run.id, env, [])

    {:ok, _pid} =
      DynamicSupervisor.start_child(
        Agentmancer.RunSupervisor,
        {RunServer, run_id: run.id, caller: self()}
      )

    receive do
      {:run_complete, ^run_id, _result} -> :ok
    end
  end
end
