defmodule Agentmancer.Execution.Artifact do
  use Agentmancer.ProjectScopedSchema

  schema "artifacts" do
    field :name, :string
    field :kind, :string
    field :content_type, :string
    field :size_bytes, :integer
    field :storage_backend, :string
    field :storage_path, :string
    field :checksum_sha256, :string
    field :metadata, :map

    belongs_to :run_attempt, Agentmancer.Execution.RunAttempt
    belongs_to :project, Agentmancer.Projects.Project

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [
      :name,
      :kind,
      :content_type,
      :size_bytes,
      :storage_backend,
      :storage_path,
      :checksum_sha256,
      :metadata,
      :run_attempt_id,
      :project_id
    ])
    |> validate_required([
      :name,
      :kind,
      :content_type,
      :size_bytes,
      :storage_backend,
      :storage_path,
      :checksum_sha256,
      :run_attempt_id
    ])
    |> foreign_key_constraint(:run_attempt_id)
    |> foreign_key_constraint(:project_id)
  end
end
