defmodule Agentmancer.Workers.ScheduleTriggerWorker do
  use Oban.Worker, queue: :triggers, max_attempts: 1

  require Logger

  alias Agentmancer.{Repo, Workflows, Execution}

  @impl Oban.Worker
  def perform(_job) do
    for trigger <- Workflows.list_due_schedules(),
        schedule_matches_now?(trigger.config, trigger.last_triggered_at) do
      {:ok, event} =
        Workflows.create_trigger_event(%{
          trigger_id: trigger.id,
          project_id: trigger.project_id,
          event_type: "cron.fire"
        })

      enqueue_runs_for_trigger(trigger, event)
      Workflows.update_trigger(trigger, %{last_triggered_at: DateTime.utc_now()})
    end

    :ok
  end

  defp schedule_matches_now?(%{"cron_expression" => cron}, last_triggered_at) do
    with {:ok, expr} <- Crontab.CronExpression.Parser.parse(cron) do
      Crontab.DateChecker.matches_date?(expr, NaiveDateTime.utc_now()) and
        not fired_this_minute?(DateTime.utc_now(), last_triggered_at)
    else
      _ ->
        Logger.warning("Invalid cron expression: #{cron}")
        false
    end
  end

  defp schedule_matches_now?(_, _), do: false

  defp fired_this_minute?(_now, nil), do: false
  defp fired_this_minute?(now, last), do: DateTime.diff(now, last, :second) < 60

  defp enqueue_runs_for_trigger(trigger, event) do
    trigger =
      Repo.preload(trigger,
        workflow_definition: [workflow_bindings: [:agent_definition]]
      )

    for binding <- trigger.workflow_definition.workflow_bindings,
        binding.enabled do
      agent_def = Repo.preload(binding.agent_definition, :active_version)

      if agent_def.active_version_id do
        {:ok, run} =
          Execution.create_run(%{
            project_id: trigger.project_id,
            workflow_definition_id: trigger.workflow_definition_id,
            workflow_binding_id: binding.id,
            agent_definition_id: binding.agent_definition_id,
            agent_version_id: agent_def.active_version_id,
            repository_id: binding.repository_id,
            trigger_id: trigger.id,
            trigger_event_id: event.id,
            status: :pending,
            number: Execution.next_run_number(trigger.project_id)
          })

        Oban.insert(Agentmancer.Workers.RunExecutionWorker.new(%{run_id: run.id}))
      end
    end
  end
end
