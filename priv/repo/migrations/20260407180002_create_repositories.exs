defmodule Agentmancer.Repo.Migrations.CreateRepositories do
  use Ecto.Migration

  def change do
    create table(:repositories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :clone_url, :string, null: false
      add :default_branch, :string, default: "main"
      add :github_owner, :string
      add :github_repo, :string
      add :mirror_path, :string
      add :last_synced_at, :utc_datetime_usec
      add :settings, :map
      add :archived_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:repositories, [:project_id, :name])
    create index(:repositories, [:github_owner, :github_repo])
  end
end
