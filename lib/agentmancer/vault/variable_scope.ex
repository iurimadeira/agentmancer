defmodule Agentmancer.Vault.VariableScope do
  use Agentmancer.Schema

  schema "variable_scopes" do
    field :level, Ecto.Enum, values: [:global, :project, :repository, :workflow, :run_override]
    field :run_id, :binary_id

    belongs_to :project, Agentmancer.Projects.Project
    belongs_to :repository, Agentmancer.Projects.Repository
    belongs_to :workflow_definition, Agentmancer.Workflows.WorkflowDefinition

    has_many :variables, Agentmancer.Vault.Variable

    timestamps()
  end

  def changeset(variable_scope, attrs) do
    variable_scope
    |> cast(attrs, [:level, :run_id, :project_id, :repository_id, :workflow_definition_id])
    |> validate_required([:level])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:repository_id)
    |> foreign_key_constraint(:workflow_definition_id)
  end
end
