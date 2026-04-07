defmodule Agentmancer.Workflows do
  import Ecto.Query
  alias Agentmancer.Repo

  alias Agentmancer.Workflows.{
    WorkflowDefinition,
    WorkflowBinding,
    Trigger,
    TriggerEvent,
    WebhookEndpoint
  }

  # Workflow Definitions

  def list_workflow_definitions(project_id) do
    WorkflowDefinition
    |> where([w], w.project_id == ^project_id and is_nil(w.archived_at))
    |> order_by(:name)
    |> Repo.all()
  end

  def get_workflow_definition!(id), do: Repo.get!(WorkflowDefinition, id)

  def get_workflow_definition_by_slug!(slug), do: Repo.get_by!(WorkflowDefinition, slug: slug)

  def list_workflow_bindings(workflow_definition_id) do
    WorkflowBinding
    |> where([b], b.workflow_definition_id == ^workflow_definition_id)
    |> order_by(:position)
    |> Repo.all()
    |> Repo.preload([:agent_definition, :repository])
  end

  def create_workflow_definition(attrs) do
    %WorkflowDefinition{} |> WorkflowDefinition.changeset(attrs) |> Repo.insert()
  end

  def update_workflow_definition(%WorkflowDefinition{} = workflow, attrs) do
    workflow |> WorkflowDefinition.changeset(attrs) |> Repo.update()
  end

  def change_workflow_definition(%WorkflowDefinition{} = workflow, attrs \\ %{}) do
    WorkflowDefinition.changeset(workflow, attrs)
  end

  # Workflow Bindings

  def create_workflow_binding(attrs) do
    %WorkflowBinding{} |> WorkflowBinding.changeset(attrs) |> Repo.insert()
  end

  def update_workflow_binding(%WorkflowBinding{} = binding, attrs) do
    binding |> WorkflowBinding.changeset(attrs) |> Repo.update()
  end

  def delete_workflow_binding(%WorkflowBinding{} = binding) do
    Repo.delete(binding)
  end

  # Triggers

  def list_triggers(workflow_definition_id) do
    Trigger
    |> where([t], t.workflow_definition_id == ^workflow_definition_id)
    |> order_by(:name)
    |> Repo.all()
  end

  def get_trigger!(id), do: Repo.get!(Trigger, id)

  def create_trigger(attrs) do
    %Trigger{} |> Trigger.changeset(attrs) |> Repo.insert()
  end

  def update_trigger(%Trigger{} = trigger, attrs) do
    trigger |> Trigger.changeset(attrs) |> Repo.update()
  end

  def change_trigger(%Trigger{} = trigger, attrs \\ %{}) do
    Trigger.changeset(trigger, attrs)
  end

  # Webhook Endpoints

  def list_webhook_endpoints(project_id) do
    WebhookEndpoint
    |> where([w], w.project_id == ^project_id)
    |> order_by(:inserted_at)
    |> Repo.all()
  end

  def get_webhook_endpoint_by_token!(path_token) do
    Repo.get_by!(WebhookEndpoint, path_token: path_token)
  end

  def create_webhook_endpoint(attrs) do
    %WebhookEndpoint{} |> WebhookEndpoint.changeset(attrs) |> Repo.insert()
  end

  # Schedule / Webhook trigger queries

  def list_due_schedules do
    Trigger
    |> where([t], t.type == :schedule and t.enabled == true)
    |> Repo.all()
  end

  def find_triggers_for_webhook(webhook_endpoint_id, event_type) do
    Trigger
    |> join(:inner, [t], w in WorkflowDefinition, on: t.workflow_definition_id == w.id)
    |> where([t, w], t.type == :webhook and t.enabled == true and is_nil(w.archived_at))
    |> where(
      [t],
      fragment("?->>'webhook_endpoint_id' = ?", t.config, ^webhook_endpoint_id) and
        fragment("?->>'event_type' = ?", t.config, ^event_type)
    )
    |> Repo.all()
  end

  # Trigger Events

  def create_trigger_event(attrs) do
    %TriggerEvent{} |> TriggerEvent.changeset(attrs) |> Repo.insert()
  end
end
