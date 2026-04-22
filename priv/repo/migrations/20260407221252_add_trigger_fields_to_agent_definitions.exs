defmodule Agentmancer.Repo.Migrations.AddTriggerFieldsToAgentDefinitions do
  use Ecto.Migration

  def change do
    alter table(:agent_definitions) do
      add :trigger_type, :string
      add :trigger_config, :map, default: %{}
      add :trigger_enabled, :boolean, default: false
      add :last_triggered_at, :utc_datetime_usec
    end
  end
end
