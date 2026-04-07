defmodule Agentmancer.Repo.Migrations.AddVariableScopesRunFk do
  use Ecto.Migration

  def change do
    alter table(:variable_scopes) do
      modify :run_id, references(:runs, type: :binary_id, on_delete: :restrict), from: :binary_id
    end
  end
end
