defmodule Agentmancer.Vault.RunEnvSnapshot do
  use Agentmancer.Schema

  schema "run_env_snapshots" do
    field :env_ciphertext, Agentmancer.Vault.EncryptedBinary
    field :scope_chain, :map

    belongs_to :run, Agentmancer.Execution.Run

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(run_env_snapshot, attrs) do
    run_env_snapshot
    |> cast(attrs, [:env_ciphertext, :scope_chain, :run_id])
    |> validate_required([:env_ciphertext, :run_id])
    |> unique_constraint(:run_id)
    |> foreign_key_constraint(:run_id)
  end
end
