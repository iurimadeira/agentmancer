defmodule Agentmancer.Projects.Seeder do
  alias Agentmancer.Repo
  alias Agentmancer.Agents
  alias Agentmancer.Workflows

  @default_agents [
    %{
      name: "PR Reviewer",
      slug: "pr-reviewer",
      kind: :pr_review,
      description: "Reviews PRs for bugs, security issues, and style",
      prompt_file: "pr_reviewer_v1.md",
      schema_file: "review.json"
    },
    %{
      name: "Auto-Fixer",
      slug: "auto-fixer",
      kind: :auto_fix,
      description: "Applies fixes for findings from PR review",
      prompt_file: "auto_fixer_v1.md",
      schema_file: "fix.json"
    },
    %{
      name: "Ticket Triager",
      slug: "ticket-triager",
      kind: :ticket_triage,
      description: "Triages incoming tickets and issues",
      prompt_file: "ticket_triager_v1.md",
      schema_file: "ticket_action.json"
    },
    %{
      name: "Digest Reporter",
      slug: "digest-reporter",
      kind: :digest,
      description: "Generates summary digest of recent activity",
      prompt_file: "digest_reporter_v1.md",
      schema_file: "digest.json"
    }
  ]

  @default_workflows [
    %{
      name: "PR Review",
      slug: "pr-review",
      agent_slug: "pr-reviewer",
      description: "Auto-review PRs on push/open"
    },
    %{
      name: "Auto-Fix",
      slug: "auto-fix",
      agent_slug: "auto-fixer",
      description: "Fix issues found in PR review"
    },
    %{
      name: "Ticket Triage",
      slug: "ticket-triage",
      agent_slug: "ticket-triager",
      description: "Triage incoming tickets"
    },
    %{
      name: "Scheduled Digest",
      slug: "scheduled-digest",
      agent_slug: "digest-reporter",
      description: "Periodic activity digest"
    }
  ]

  @default_triggers [
    %{
      name: "PR Events",
      type: :webhook,
      workflow_slug: "pr-review",
      config: %{"event_filter" => ["pull_request.opened", "pull_request.synchronize"]}
    },
    %{
      name: "Ticket Events",
      type: :webhook,
      workflow_slug: "ticket-triage",
      config: %{"event_filter" => ["issues.opened", "issues.labeled"]}
    },
    %{
      name: "Weekly Digest",
      type: :schedule,
      workflow_slug: "scheduled-digest",
      config: %{"cron_expression" => "0 9 * * 1", "timezone" => "UTC"}
    },
    %{
      name: "Manual PR Review",
      type: :manual,
      workflow_slug: "pr-review",
      config: %{"require_input" => true}
    },
    %{
      name: "Manual Digest",
      type: :manual,
      workflow_slug: "scheduled-digest",
      config: %{"require_input" => false}
    }
  ]

  def seed_defaults(project) do
    Repo.transaction(fn ->
      profiles = seed_runtime_profiles(project)
      agents = seed_agents(project, profiles)
      workflows = seed_workflows(project, agents)
      seed_triggers(project, workflows)
    end)

    project
  end

  defp seed_runtime_profiles(project) do
    defaults = [
      %{name: "codex-default", engine: :codex_cli, model: "o3-mini", timeout_seconds: 600},
      %{
        name: "claude-default",
        engine: :claude_code_cli,
        model: "claude-sonnet-4-5-20250514",
        timeout_seconds: 600
      }
    ]

    for attrs <- defaults, into: %{} do
      {:ok, profile} =
        Agents.create_runtime_profile(Map.put(attrs, :project_id, project.id))

      {attrs.name, profile}
    end
  end

  defp seed_agents(project, profiles) do
    claude_profile = profiles["claude-default"]

    for agent_spec <- @default_agents, into: %{} do
      prompt = load_template(agent_spec.prompt_file)
      schema = load_schema(agent_spec.schema_file)

      {:ok, agent_def} =
        Agents.create_agent_definition(%{
          project_id: project.id,
          name: agent_spec.name,
          slug: agent_spec.slug,
          kind: agent_spec.kind,
          description: agent_spec.description,
          runtime_profile_id: claude_profile.id
        })

      {:ok, _version} =
        Agents.create_version(agent_def, %{
          system_prompt: prompt,
          output_schema: schema,
          change_note: "Initial default version",
          created_by: "system"
        })

      {agent_spec.slug, Repo.reload!(agent_def)}
    end
  end

  defp seed_workflows(project, agents) do
    for wf_spec <- @default_workflows, into: %{} do
      agent = Map.fetch!(agents, wf_spec.agent_slug)

      {:ok, workflow} =
        Workflows.create_workflow_definition(%{
          project_id: project.id,
          name: wf_spec.name,
          slug: wf_spec.slug,
          description: wf_spec.description
        })

      {:ok, _binding} =
        Workflows.create_workflow_binding(%{
          project_id: project.id,
          workflow_definition_id: workflow.id,
          agent_definition_id: agent.id,
          position: 1
        })

      {wf_spec.slug, workflow}
    end
  end

  defp seed_triggers(project, workflows) do
    for trigger_spec <- @default_triggers do
      workflow = Map.fetch!(workflows, trigger_spec.workflow_slug)

      {:ok, _trigger} =
        Workflows.create_trigger(%{
          project_id: project.id,
          workflow_definition_id: workflow.id,
          type: trigger_spec.type,
          name: trigger_spec.name,
          enabled: false,
          config: trigger_spec.config
        })
    end
  end

  defp load_template(filename) do
    path = Application.app_dir(:agentmancer, ["priv", "templates", filename])

    if File.exists?(path) do
      File.read!(path)
    else
      "Default system prompt for #{Path.rootname(filename)}. Edit this in the agent settings."
    end
  end

  defp load_schema(filename) do
    path = Application.app_dir(:agentmancer, ["priv", "templates", "schemas", filename])

    if File.exists?(path) do
      path |> File.read!() |> Jason.decode!()
    else
      %{}
    end
  end
end
