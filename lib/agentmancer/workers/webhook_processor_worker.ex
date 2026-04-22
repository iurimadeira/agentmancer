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
        workflow_definition: [workflow_bindings: [:repository]]
      )

    for binding <- trigger.workflow_definition.workflow_bindings,
        binding.enabled,
        not is_nil(binding.repository_id),
        not is_nil(binding.skill_source),
        not is_nil(binding.skill_slug) do
      {:ok, run} =
        Execution.create_run(%{
          project_id: trigger.project_id,
          workflow_definition_id: trigger.workflow_definition_id,
          workflow_binding_id: binding.id,
          repository_id: binding.repository_id,
          trigger_id: trigger.id,
          trigger_event_id: event.id,
          status: :pending,
          number: Execution.next_run_number(trigger.project_id),
          skill_source: binding.skill_source,
          skill_slug: binding.skill_slug,
          skill_name:
            binding.skill_slug |> to_string() |> String.replace("-", " ") |> String.capitalize()
        })

      Oban.insert(Agentmancer.Workers.RunExecutionWorker.new(%{run_id: run.id}))
    end
  end
end
