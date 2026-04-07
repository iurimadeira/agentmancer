defmodule Agentmancer.Projects.Seeder do
  alias Agentmancer.Repo
  alias Agentmancer.Agents
  alias Agentmancer.Catalog
  alias Agentmancer.Workflows

  @default_agent_slugs ~w(pr-reviewer auto-fixer ticket-triager digest-reporter)

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

    for slug <- @default_agent_slugs,
        entry = Catalog.get_catalog_entry_by_slug(slug),
        entry != nil,
        into: %{} do
      {:ok, agent} = Catalog.install_to_project(entry, project.id, claude_profile.id)
      {slug, agent}
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
end
