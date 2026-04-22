defmodule Agentmancer.Reviews do
  import Ecto.Query
  alias Agentmancer.Repo
  alias Agentmancer.Reviews.{Finding, ReviewThread, CommentAction}

  # Findings

  def create_findings(run_attempt_id, findings_attrs) when is_list(findings_attrs) do
    results =
      Enum.map(findings_attrs, fn attrs ->
        attrs = Map.put(attrs, :run_attempt_id, run_attempt_id)
        %Finding{} |> Finding.changeset(attrs) |> Repo.insert()
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if errors == [] do
      {:ok, Enum.map(results, fn {:ok, finding} -> finding end)}
    else
      {:error, errors}
    end
  end

  def list_findings_for_run(run_attempt_id) do
    Finding
    |> where([f], f.run_attempt_id == ^run_attempt_id)
    |> order_by([:file_path, :line_start])
    |> Repo.all()
  end

  def list_findings_for_pr(repository_id, pr_number) do
    Finding
    |> join(:inner, [f], r in Agentmancer.Execution.Run,
      on:
        f.repository_id == ^repository_id and
          r.repository_id == ^repository_id and
          r.pr_number == ^pr_number
    )
    |> join(:inner, [f, r], a in Agentmancer.Execution.RunAttempt,
      on: a.run_id == r.id and a.id == f.run_attempt_id
    )
    |> order_by([f], [:file_path, :line_start])
    |> select([f], f)
    |> Repo.all()
  end

  def update_finding_status(%Finding{} = finding, status) do
    finding |> Finding.changeset(%{status: status}) |> Repo.update()
  end

  def get_finding!(id), do: Repo.get!(Finding, id)

  # Review Threads

  def create_review_thread(attrs) do
    %ReviewThread{} |> ReviewThread.changeset(attrs) |> Repo.insert()
  end

  def list_threads_for_pr(repository_id, pr_number) do
    ReviewThread
    |> where([t], t.repository_id == ^repository_id and t.pr_number == ^pr_number)
    |> order_by(:inserted_at)
    |> Repo.all()
  end

  def get_review_thread!(id), do: Repo.get!(ReviewThread, id)

  # Comment Actions

  def create_comment_action(attrs) do
    %CommentAction{} |> CommentAction.changeset(attrs) |> Repo.insert()
  end

  def list_comment_actions(review_thread_id) do
    CommentAction
    |> where([c], c.review_thread_id == ^review_thread_id)
    |> order_by(:inserted_at)
    |> Repo.all()
  end
end
