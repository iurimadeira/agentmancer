defmodule Agentmancer.Workflows.TriggerEvent do
  use Agentmancer.ProjectScopedSchema

  schema "trigger_events" do
    field :event_type, :string
    field :payload, :map
    field :headers, :map
    field :source_ip, :string
    field :signature_valid, :boolean
    field :rejected_reason, :string

    belongs_to :project, Agentmancer.Projects.Project
    belongs_to :trigger, Agentmancer.Workflows.Trigger
    belongs_to :webhook_endpoint, Agentmancer.Workflows.WebhookEndpoint
    belongs_to :run, Agentmancer.Execution.Run

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(trigger_event, attrs) do
    trigger_event
    |> cast(attrs, [
      :event_type,
      :payload,
      :headers,
      :source_ip,
      :signature_valid,
      :rejected_reason,
      :project_id,
      :trigger_id,
      :webhook_endpoint_id,
      :run_id
    ])
    |> validate_required([:event_type, :project_id])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:trigger_id)
    |> foreign_key_constraint(:webhook_endpoint_id)
    |> foreign_key_constraint(:run_id)
  end
end
