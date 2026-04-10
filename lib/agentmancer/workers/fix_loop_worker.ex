defmodule Agentmancer.Workers.FixLoopWorker do
  use Oban.Worker, queue: :fix_loops, max_attempts: 2

  require Logger

  alias Agentmancer.Execution
  alias Agentmancer.Workspace.{Git, Paths}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"run_id" => run_id, "iteration" => iteration}}) do
    parent_run = Execution.get_run_with_associations!(run_id)

    if iteration > parent_run.max_iterations do
      Logger.info("FixLoopWorker: max iterations reached for run #{run_id}")

      Execution.update_run_status(parent_run, :failure, %{
        error_message: "Max fix iterations (#{parent_run.max_iterations}) reached"
      })

      return_ok()
    end

    repo = parent_run.repository
    branch = parent_run.branch || repo.default_branch || "main"
    mirror_path = Paths.mirror_path(repo.id)

    case detect_stale(mirror_path, branch, parent_run.pr_head_sha) do
      :stale ->
        Logger.info("FixLoopWorker: branch #{branch} has diverged, marking stale")

        Execution.update_run_status(parent_run, :stale, %{
          error_message: "Branch diverged during fix loop"
        })

        :ok

      :current ->
        create_child_run(parent_run, iteration)
    end
  end

  defp detect_stale(mirror_path, branch, expected_sha) when is_binary(expected_sha) do
    case Git.current_remote_head(mirror_path, branch) do
      {:ok, ^expected_sha} -> :current
      {:ok, _other} -> :stale
      {:error, _} -> :current
    end
  end

  defp detect_stale(_mirror_path, _branch, _nil_sha), do: :current

  defp create_child_run(parent_run, iteration) do
    {:ok, child_run} =
      Execution.create_run(%{
        project_id: parent_run.project_id,
        workflow_definition_id: parent_run.workflow_definition_id,
        workflow_binding_id: parent_run.workflow_binding_id,
        repository_id: parent_run.repository_id,
        trigger_id: parent_run.trigger_id,
        parent_run_id: parent_run.id,
        status: :pending,
        number: Execution.next_run_number(parent_run.project_id),
        iteration: iteration,
        max_iterations: parent_run.max_iterations,
        branch: parent_run.branch,
        pr_number: parent_run.pr_number,
        pr_head_sha: parent_run.pr_head_sha,
        input: parent_run.input,
        skill_source: parent_run.skill_source,
        skill_slug: parent_run.skill_slug,
        skill_name: parent_run.skill_name,
        skill_body: parent_run.skill_body,
        skill_metadata: parent_run.skill_metadata
      })

    Oban.insert(Agentmancer.Workers.RunExecutionWorker.new(%{run_id: child_run.id}))
    :ok
  end

  defp return_ok, do: :ok
end
