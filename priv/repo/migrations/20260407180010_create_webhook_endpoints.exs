defmodule Agentmancer.Repo.Migrations.CreateWebhookEndpoints do
  use Ecto.Migration

  def change do
    create table(:webhook_endpoints, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false
      add :path_token, :string, null: false
      add :source, :string, null: false
      add :secret_ciphertext, :binary
      add :allowed_ips, {:array, :string}
      add :enabled, :boolean, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:webhook_endpoints, [:path_token])
  end
end
