defmodule Agentmancer.Workers.PostFindingsWorker do
  use Oban.Worker, queue: :reviews, max_attempts: 3

  require Logger

  alias Agentmancer.{Reviews, Execution}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"run_id" => run_id}}) do
    run = Execution.get_run_with_associations!(run_id)
    repo = run.repository

    unless repo.github_owner && repo.github_repo && run.pr_number do
      Logger.info("PostFindingsWorker skipped: missing GitHub info for run #{run_id}")
      return_ok()
    end

    latest_attempt = run.attempts |> Enum.max_by(& &1.attempt_number, fn -> nil end)

    unless latest_attempt do
      Logger.info("PostFindingsWorker skipped: no attempts for run #{run_id}")
      return_ok()
    end

    findings = Reviews.list_findings_for_run(latest_attempt.id)

    if findings == [] do
      Logger.info("PostFindingsWorker: no findings to post for run #{run_id}")
      return_ok()
    end

    comments = build_review_comments(findings)

    review_payload = %{
      "owner" => repo.github_owner,
      "repo" => repo.github_repo,
      "pr_number" => run.pr_number,
      "token" => resolve_github_token(run.project_id),
      "event" => "COMMENT",
      "body" => "Agentmancer found #{length(findings)} issue(s)",
      "comments" => comments
    }

    {:ok, delivery} =
      Agentmancer.Delivery.create_delivery(%{
        channel: :github_pr_review,
        config: review_payload,
        payload: review_payload,
        project_id: run.project_id,
        run_id: run.id
      })

    Oban.insert(Agentmancer.Workers.DeliveryWorker.new(%{delivery_id: delivery.id}))

    for finding <- findings do
      Reviews.create_review_thread(%{
        pr_number: run.pr_number,
        file_path: finding.file_path,
        line_number: finding.line_start,
        status: :open,
        last_actor: "agentmancer",
        finding_id: finding.id,
        project_id: run.project_id,
        repository_id: repo.id
      })
    end

    :ok
  end

  defp build_review_comments(findings) do
    Enum.map(findings, fn finding ->
      %{
        "path" => finding.file_path,
        "line" => finding.line_start || 1,
        "body" => format_finding(finding)
      }
    end)
  end

  defp format_finding(finding) do
    severity_badge =
      case finding.severity do
        :critical -> "**CRITICAL**"
        :error -> "**ERROR**"
        :warning -> "WARNING"
        :info -> "INFO"
      end

    body = "#{severity_badge}: #{finding.title}\n\n#{finding.body}"

    if finding.suggested_fix do
      body <> "\n\n**Suggested fix:**\n```\n#{finding.suggested_fix}\n```"
    else
      body
    end
  end

  defp resolve_github_token(project_id) do
    env = Agentmancer.Vault.resolve_env(project_id: project_id)
    Map.get(env, "GITHUB_TOKEN", "")
  end

  defp return_ok, do: :ok
end
