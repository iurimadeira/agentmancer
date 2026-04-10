defmodule AgentmancerWeb.SkillLive.Index do
  use AgentmancerWeb, :live_view

  alias Agentmancer.Skills

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Global Skills",
       skills: Skills.list_global_skills()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Global Skills
        <:subtitle>Read-only skills bundled with AgentMancer.</:subtitle>
      </.header>

      <div :if={@skills == []} class="text-base-content/60 py-12 text-center mt-6">
        No global skills are available.
      </div>

      <div id="global-skills-grid" class="grid grid-cols-1 xl:grid-cols-2 gap-6 mt-6">
        <div :for={skill <- @skills} id={"global-skill-#{skill.slug}"} class="card bg-base-200">
          <div class="card-body">
            <div class="flex items-start justify-between gap-3">
              <div>
                <div class="flex items-center gap-2">
                  <.icon name={skill.icon || "hero-cpu-chip"} class="size-5 text-primary" />
                  <h3 class="card-title text-sm">{skill.name}</h3>
                </div>
                <p :if={skill.description} class="text-sm text-base-content/60 mt-2">
                  {skill.description}
                </p>
              </div>
              <span class="badge badge-sm badge-outline">global</span>
            </div>

            <div class="flex flex-wrap gap-1 mt-3">
              <span class="badge badge-sm badge-ghost">{skill.kind || "custom"}</span>
              <span :for={tag <- skill.tags} class="badge badge-sm badge-outline">{tag}</span>
            </div>

            <div class="text-xs font-mono text-base-content/50 mt-3">{skill.slug}</div>

            <details class="mt-4">
              <summary class="cursor-pointer text-sm text-primary">View skill</summary>
              <div class="space-y-4 mt-3">
                <pre class="whitespace-pre-wrap text-sm bg-base-300 p-4 rounded-lg max-h-96 overflow-y-auto"><code>{skill.body}</code></pre>

                <div :if={skill.output_schema} class="space-y-2">
                  <h4 class="text-xs font-semibold uppercase tracking-wide text-base-content/50">
                    Output Schema
                  </h4>
                  <pre class="text-xs bg-base-300 p-3 rounded-lg overflow-x-auto"><code>{Jason.encode!(skill.output_schema, pretty: true)}</code></pre>
                </div>

                <div :if={skill.suggested_trigger != %{}} class="space-y-2">
                  <h4 class="text-xs font-semibold uppercase tracking-wide text-base-content/50">
                    Suggested Trigger
                  </h4>
                  <pre class="text-xs bg-base-300 p-3 rounded-lg overflow-x-auto"><code>{Jason.encode!(skill.suggested_trigger, pretty: true)}</code></pre>
                </div>
              </div>
            </details>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
