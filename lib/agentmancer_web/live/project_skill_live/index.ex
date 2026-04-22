defmodule AgentmancerWeb.ProjectSkillLive.Index do
  use AgentmancerWeb, :live_view

  alias Agentmancer.Projects
  alias Agentmancer.Skills

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    project = Projects.get_project_by_slug!(slug)
    repos = Projects.list_repositories(project.id)

    {:ok,
     assign(socket,
       page_title: "Skills - #{project.name}",
       project: project,
       global_skills: Skills.list_global_skills(),
       repository_skills: Enum.map(repos, &{&1, Skills.list_repository_skills(&1)})
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Skills
        <:subtitle>{@project.name}</:subtitle>
        <:actions>
          <.link navigate={~p"/projects/#{@project.slug}"} class="btn btn-ghost">
            <.icon name="hero-arrow-left" class="size-4" /> Project
          </.link>
          <.link navigate={~p"/skills"} class="btn btn-ghost">
            <.icon name="hero-book-open" class="size-4" /> Global Skills
          </.link>
        </:actions>
      </.header>

      <div class="mt-6 space-y-8">
        <section>
          <div class="mb-4">
            <h2 class="text-lg font-semibold">Global Skills</h2>
            <p class="text-sm text-base-content/60">
              Available to every project in this AgentMancer instance.
            </p>
          </div>
          <div id="project-global-skills" class="grid grid-cols-1 xl:grid-cols-2 gap-6">
            <div
              :for={skill <- @global_skills}
              id={"project-global-skill-#{skill.slug}"}
              class="card bg-base-200"
            >
              <div class="card-body">
                <div class="flex items-center gap-2">
                  <.icon name={skill.icon || "hero-cpu-chip"} class="size-5 text-primary" />
                  <h3 class="card-title text-sm">{skill.name}</h3>
                  <span class="badge badge-sm badge-outline">global</span>
                </div>
                <p :if={skill.description} class="text-sm text-base-content/60 mt-2">
                  {skill.description}
                </p>
                <div class="flex flex-wrap gap-1 mt-3">
                  <span class="badge badge-sm badge-ghost">{skill.kind || "custom"}</span>
                  <span :for={tag <- skill.tags} class="badge badge-sm badge-outline">{tag}</span>
                </div>
                <div class="text-xs font-mono text-base-content/50 mt-3">{skill.slug}</div>
                <details class="mt-4">
                  <summary class="cursor-pointer text-sm text-primary">View skill</summary>
                  <pre class="whitespace-pre-wrap text-sm bg-base-300 p-4 rounded-lg max-h-96 overflow-y-auto mt-3"><code>{skill.body}</code></pre>
                </details>
              </div>
            </div>
          </div>
        </section>

        <section>
          <div class="mb-4">
            <h2 class="text-lg font-semibold">Repository Skills</h2>
            <p class="text-sm text-base-content/60">
              Discovered from <span class="font-mono text-xs">skills/*/SKILL.md</span>
              on each repository's default branch.
            </p>
          </div>

          <div :if={@repository_skills == []} class="card bg-base-200">
            <div class="card-body text-sm text-base-content/60">
              Add a repository to this project to discover local skills.
            </div>
          </div>

          <div
            :for={{repo, skills} <- @repository_skills}
            id={"repository-skills-#{repo.id}"}
            class="card bg-base-200 mb-6"
          >
            <div class="card-body">
              <div class="flex items-center justify-between gap-4">
                <div>
                  <h3 class="card-title text-sm">{repo.name}</h3>
                  <div class="text-xs font-mono text-base-content/50 mt-1">{repo.clone_url}</div>
                </div>
                <span class="badge badge-sm badge-outline">{length(skills)} skills</span>
              </div>

              <div :if={skills == []} class="text-sm text-base-content/60 mt-4">
                No repository-local skills found.
              </div>

              <div :if={skills != []} class="grid grid-cols-1 xl:grid-cols-2 gap-4 mt-4">
                <div
                  :for={skill <- skills}
                  class="rounded-lg border border-base-300/60 bg-base-300/40 p-4"
                >
                  <div class="flex items-center gap-2">
                    <.icon name={skill.icon || "hero-cpu-chip"} class="size-5 text-primary" />
                    <div class="font-medium text-sm">{skill.name}</div>
                    <span class="badge badge-sm badge-outline">repository</span>
                  </div>
                  <p :if={skill.description} class="text-sm text-base-content/60 mt-2">
                    {skill.description}
                  </p>
                  <div class="flex flex-wrap gap-1 mt-3">
                    <span class="badge badge-sm badge-ghost">{skill.kind || "custom"}</span>
                    <span :for={tag <- skill.tags} class="badge badge-sm badge-outline">{tag}</span>
                  </div>
                  <div class="text-xs font-mono text-base-content/50 mt-3">{skill.slug}</div>
                  <details class="mt-4">
                    <summary class="cursor-pointer text-sm text-primary">View skill</summary>
                    <pre class="whitespace-pre-wrap text-sm bg-base-300 p-4 rounded-lg max-h-96 overflow-y-auto mt-3"><code>{skill.body}</code></pre>
                  </details>
                </div>
              </div>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
