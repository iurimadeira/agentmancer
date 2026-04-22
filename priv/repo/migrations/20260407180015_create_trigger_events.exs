defmodule Agentmancer.Repo.Migrations.CreateTriggerEvents do
  use Ecto.Migration

  def change do
    create table(:trigger_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false
      add :trigger_id, references(:triggers, type: :binary_id, on_delete: :restrict), null: false

      add :webhook_endpoint_id,
          references(:webhook_endpoints, type: :binary_id, on_delete: :restrict)

      add :event_type, :string, null: false
      add :payload, :map
      add :headers, :map
      add :source_ip, :string
      add :signature_valid, :boolean
      add :run_id, references(:runs, type: :binary_id, on_delete: :restrict)
      add :rejected_reason, :string

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:trigger_events, [:trigger_id])
    create index(:trigger_events, [:inserted_at])
    create index(:trigger_events, [:run_id])
  end
end
