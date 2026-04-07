defmodule Agentmancer.Workers.WebhookProcessorWorker do
  use Oban.Worker, queue: :triggers, max_attempts: 3

  require Logger

  alias Agentmancer.{Repo, Workflows, Execution}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"trigger_event_id" => trigger_event_id}}) do
    event = Repo.get!(Workflows.TriggerEvent, trigger_event_id)
    endpoint = Repo.get!(Workflows.WebhookEndpoint, event.webhook_endpoint_id)
    event_type = event.event_type

    triggers = Workflows.find_triggers_for_webhook(endpoint.id, event_type)

    for trigger <- triggers do
      enqueue_runs_for_trigger(trigger, event)
    end

    :ok
  end

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
