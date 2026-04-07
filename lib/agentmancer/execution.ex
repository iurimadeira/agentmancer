defmodule Agentmancer.Execution do
  import Ecto.Query
  alias Agentmancer.Repo

  alias Agentmancer.Execution.{
    Run,
    RunAttempt,
    RunLog,
    Artifact,
    WorkspaceLock
  }

  # Runs

  def list_runs(opts \\ []) do
    query = Run |> order_by(desc: :inserted_at)

    query =
      case Keyword.get(opts, :project_id) do
        nil -> query
        id -> where(query, [r], r.project_id == ^id)
      end

    query =
      case Keyword.get(opts, :status) do
        nil -> query
        status -> where(query, [r], r.status == ^status)
      end

    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    query |> limit(^limit) |> offset(^offset) |> Repo.all()
  end

  def get_run!(id), do: Repo.get!(Run, id)

  def get_run_with_associations!(id) do
    Run
    |> Repo.get!(id)
    |> Repo.preload([
      :project,
      :workflow_definition,
      :agent_version,
      :repository,
      :trigger,
      attempts: :run,
      agent_definition: :runtime_profile
    ])
  end

  def create_run(attrs) do
    %Run{} |> Run.changeset(attrs) |> Repo.insert()
  end

  def update_run_status(%Run{} = run, status, attrs \\ %{}) do
    run |> Run.changeset(Map.put(attrs, :status, status)) |> Repo.update()
  end

  def fail_run(%Run{} = run, error_attrs) do
    attrs =
      error_attrs
      |> Map.put(:status, :failure)
      |> Map.put(:completed_at, DateTime.utc_now())

    run |> Run.changeset(attrs) |> Repo.update()
  end

  def cancel_run(%Run{} = run) do
    run
    |> Run.changeset(%{
      status: :cancelled,
      cancelled_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  def complete_run(%Run{} = run, result_attrs) do
    attrs =
      result_attrs
      |> Map.put(:status, :success)
      |> Map.put(:completed_at, DateTime.utc_now())

    run |> Run.changeset(attrs) |> Repo.update()
  end

  def next_run_number(project_id) do
    Run
    |> where([r], r.project_id == ^project_id)
    |> select([r], coalesce(max(r.number), 0) + 1)
    |> Repo.one()
  end

  def count_runs(opts \\ []) do
    query = Run

    query =
      case Keyword.get(opts, :status) do
        nil -> query
        status -> where(query, [r], r.status == ^status)
      end

    Repo.aggregate(query, :count)
  end

  def count_recent_completions(since) do
    Run
    |> where([r], r.status == :success and r.completed_at >= ^since)
    |> Repo.aggregate(:count)
  end

  # Run Attempts

  def create_attempt(%Run{} = run, attrs) do
    next_attempt =
      RunAttempt
      |> where([a], a.run_id == ^run.id)
      |> select([a], coalesce(max(a.attempt_number), 0) + 1)
      |> Repo.one()

    attempt_attrs =
      attrs
      |> Map.put(:attempt_number, next_attempt)
      |> Map.put(:run_id, run.id)
      |> Map.put(:project_id, run.project_id)

    %RunAttempt{} |> RunAttempt.changeset(attempt_attrs) |> Repo.insert()
  end

  # Run Logs

  def insert_log_batch(entries) when is_list(entries) do
    now = DateTime.utc_now()

    entries =
      Enum.map(entries, fn entry ->
        entry
        |> Map.put_new(:id, Ecto.UUID.generate())
        |> Map.put_new(:inserted_at, now)
      end)

    Repo.insert_all(RunLog, entries)
  end

  def list_logs(run_attempt_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    RunLog
    |> where([l], l.run_attempt_id == ^run_attempt_id)
    |> order_by(:timestamp)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  # Artifacts

  def create_artifact(attrs) do
    %Artifact{} |> Artifact.changeset(attrs) |> Repo.insert()
  end

  def list_artifacts(run_attempt_id) do
    Artifact
    |> where([a], a.run_attempt_id == ^run_attempt_id)
    |> order_by(:inserted_at)
    |> Repo.all()
  end

  # Workspace Locks

  def acquire_workspace_lock(attrs) do
    attrs = Map.put_new(attrs, :locked_at, DateTime.utc_now())
    %WorkspaceLock{} |> WorkspaceLock.changeset(attrs) |> Repo.insert()
  end

  def release_workspace_lock(%WorkspaceLock{} = lock) do
    lock
    |> WorkspaceLock.changeset(%{released_at: DateTime.utc_now()})
    |> Repo.update()
  end
end
