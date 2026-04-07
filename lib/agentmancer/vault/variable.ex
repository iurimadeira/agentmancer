defmodule Agentmancer.Vault.Variable do
  use Agentmancer.Schema

  schema "variables" do
    field :key, :string
    field :value_ciphertext, Agentmancer.Vault.EncryptedBinary
    field :value, :string, virtual: true
    field :is_secret, :boolean, default: false
    field :description, :string

    belongs_to :variable_scope, Agentmancer.Vault.VariableScope

    timestamps()
  end

  def changeset(variable, attrs) do
    variable
    |> cast(attrs, [:key, :value_ciphertext, :value, :is_secret, :description, :variable_scope_id])
    |> validate_required([:key, :value_ciphertext, :variable_scope_id])
    |> foreign_key_constraint(:variable_scope_id)
  end
end
