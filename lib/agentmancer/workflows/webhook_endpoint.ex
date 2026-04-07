defmodule Agentmancer.Workflows.WebhookEndpoint do
  use Agentmancer.ProjectScopedSchema

  schema "webhook_endpoints" do
    field :path_token, :string
    field :source, Ecto.Enum, values: [:github, :gitlab, :jira, :linear, :custom]
    field :secret_ciphertext, Agentmancer.Vault.EncryptedBinary
    field :allowed_ips, {:array, :string}
    field :enabled, :boolean, default: true

    belongs_to :project, Agentmancer.Projects.Project

    timestamps()
  end

  def changeset(webhook_endpoint, attrs) do
    webhook_endpoint
    |> cast(attrs, [:path_token, :source, :secret_ciphertext, :allowed_ips, :enabled, :project_id])
    |> validate_required([:path_token, :source])
    |> unique_constraint(:path_token)
    |> foreign_key_constraint(:project_id)
  end
end
