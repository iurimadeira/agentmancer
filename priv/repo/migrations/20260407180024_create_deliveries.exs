defmodule Agentmancer.Repo.Migrations.CreateDeliveries do
  use Ecto.Migration

  def change do
    create table(:deliveries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false
      add :run_id, references(:runs, type: :binary_id, on_delete: :restrict), null: false
      add :channel, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :config, :map
      add :payload, :map
      add :response, :map
      add :error_message, :text
      add :attempts, :integer, default: 0
      add :max_attempts, :integer, default: 3
      add :delivered_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:deliveries, [:run_id])
    create index(:deliveries, [:status])
  end
end
