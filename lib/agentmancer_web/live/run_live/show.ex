defmodule AgentmancerWeb.RunLive.Show do
  use AgentmancerWeb, :live_view

  alias Agentmancer.Execution

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    run = Execution.get_run_with_associations!(id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Agentmancer.PubSub, "run:#{run.id}")
    end

    attempts = run.attempts
    latest_attempt = List.first(Enum.sort_by(attempts, & &1.attempt_number, :desc))

    logs =
      if latest_attempt do
        Execution.list_logs(latest_attempt.id, limit: 200)
      else
        []
      end

    artifacts =
      if latest_attempt do
        Execution.list_artifacts(latest_attempt.id)
      else
        []
      end

    {:ok,
     assign(socket,
       page_title: "Run ##{run.number}",
       run: run,
       attempts: attempts,
       latest_attempt: latest_attempt,
       logs: logs,
       artifacts: artifacts
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:log, log_entry}, socket) do
    {:noreply, assign(socket, logs: socket.assigns.logs ++ [log_entry])}
  end

  def handle_info({:run_updated, run}, socket) do
    run = Execution.get_run_with_associations!(run.id)
    attempts = run.attempts
    latest_attempt = List.first(Enum.sort_by(attempts, & &1.attempt_number, :desc))

    {:noreply, assign(socket, run: run, attempts: attempts, latest_attempt: latest_attempt)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("cancel_run", _params, socket) do
    case Execution.cancel_run(socket.assigns.run) do
      {:ok, run} ->
        run = Execution.get_run_with_associations!(run.id)
        {:noreply, socket |> put_flash(:info, "Run cancelled.") |> assign(run: run)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel run.")}
    end
  end

  def handle_event("retry_run", _params, socket) do
    {:noreply, put_flash(socket, :info, "Retry not yet implemented from the UI.")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Run #{@run.number}
        <:subtitle>
          <span class={["badge", status_color(@run.status)]}>{@run.status}</span>
          <span :if={@run.branch} class="ml-2 text-xs font-mono">{@run.branch}</span>
        </:subtitle>
        <:actions>
          <.link navigate={~p"/runs"} class="btn btn-ghost">
            <.icon name="hero-arrow-left" class="size-4" /> Runs
          </.link>
          <button
            :if={@run.status in [:pending, :preparing, :running]}
            phx-click="cancel_run"
            class="btn btn-error btn-outline"
            data-confirm="Cancel this run?"
          >
            Cancel
          </button>
          <button
            :if={@run.status in [:failure, :timed_out]}
            phx-click="retry_run"
            class="btn btn-warning btn-outline"
          >
            Retry
          </button>
        </:actions>
      </.header>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mt-6">
        <div class="lg:col-span-2 space-y-6">
          <div class="card bg-base-200">
            <div class="card-body">
              <h3 class="card-title text-sm">Timeline</h3>
              <ul class="steps steps-vertical text-sm">
                <li class={["step", step_class(:created, @run)]}>
                  <div class="text-left">
                    <div>Created</div>
                    <div class="text-xs text-base-content/60">{format_dt(@run.inserted_at)}</div>
                  </div>
                </li>
                <li class={["step", step_class(:started, @run)]}>
                  <div class="text-left">
                    <div>Started</div>
                    <div class="text-xs text-base-content/60">{format_dt(@run.started_at)}</div>
                  </div>
                </li>
                <li class={["step", step_class(:completed, @run)]}>
                  <div class="text-left">
                    <div>{terminal_label(@run.status)}</div>
                    <div class="text-xs text-base-content/60">
                      {format_dt(@run.completed_at || @run.cancelled_at)}
                    </div>
                  </div>
                </li>
              </ul>
            </div>
          </div>

          <div class="card bg-base-200">
            <div class="card-body">
              <h3 class="card-title text-sm">Logs</h3>
              <div :if={@logs == []} class="text-base-content/60 text-sm">No logs yet.</div>
              <div
                :if={@logs != []}
                id="log-viewer"
                phx-hook="ScrollBottom"
                class="bg-base-300 rounded-lg p-3 max-h-96 overflow-y-auto font-mono text-xs space-y-0.5"
              >
                <div :for={log <- @logs} class="flex gap-2">
                  <span class="text-base-content/40 shrink-0">{format_timestamp(log.timestamp)}</span>
                  <span class={["shrink-0", log_level_color(log.level)]}>[{log.level}]</span>
                  <span class="break-all">{log.message}</span>
                </div>
              </div>
            </div>
          </div>

          <div :if={@run.output} class="card bg-base-200">
            <div class="card-body">
              <h3 class="card-title text-sm">Output</h3>
              <pre class="text-xs bg-base-300 p-3 rounded-lg overflow-x-auto"><code>{Jason.encode!(@run.output, pretty: true)}</code></pre>
            </div>
          </div>

          <div :if={@run.error_message} class="card bg-error/10 border border-error/30">
            <div class="card-body">
              <h3 class="card-title text-sm text-error">Error</h3>
              <pre class="text-xs whitespace-pre-wrap">{@run.error_message}</pre>
            </div>
          </div>
        </div>

        <div class="space-y-6">
          <div class="card bg-base-200">
            <div class="card-body">
              <h3 class="card-title text-sm">Details</h3>
              <.list>
                <:item title="Project">{if @run.project, do: @run.project.name, else: "-"}</:item>
                <:item title="Workflow">
                  {if @run.workflow_definition, do: @run.workflow_definition.name, else: "-"}
                </:item>
                <:item title="Agent">
                  {if @run.agent_definition, do: @run.agent_definition.name, else: "-"}
                </:item>
                <:item title="Model">{model_label(@run)}</:item>
                <:item title="Repository">
                  {if @run.repository, do: @run.repository.name, else: "-"}
                </:item>
                <:item title="Iteration">{@run.iteration} / {@run.max_iterations}</:item>
                <:item title="Attempt">{@run.current_attempt} / {@run.max_attempts}</:item>
              </.list>
            </div>
          </div>

          <div :if={@latest_attempt} class="card bg-base-200">
            <div class="card-body">
              <h3 class="card-title text-sm">Latest Attempt</h3>
              <.list>
                <:item title="Number">{@latest_attempt.attempt_number}</:item>
                <:item title="Status">{@latest_attempt.status}</:item>
                <:item title="Engine">{@latest_attempt.engine}</:item>
                <:item title="Duration">
                  {if @latest_attempt.duration_ms,
                    do: "#{div(@latest_attempt.duration_ms, 1000)}s",
                    else: "-"}
                </:item>
              </.list>
            </div>
          </div>

          <div :if={@artifacts != []} class="card bg-base-200">
            <div class="card-body">
              <h3 class="card-title text-sm">Artifacts</h3>
              <div
                :for={artifact <- @artifacts}
                class="flex items-center gap-2 py-1.5 border-b border-base-300 last:border-0"
              >
                <.icon name="hero-document" class="size-4 text-base-content/60" />
                <div class="flex-1 min-w-0">
                  <div class="text-sm truncate">{artifact.name}</div>
                  <div class="text-xs text-base-content/50">
                    {artifact.kind} - {format_bytes(artifact.size_bytes)}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp status_color(:success), do: "badge-success"
  defp status_color(:failure), do: "badge-error"
  defp status_color(:running), do: "badge-warning"
  defp status_color(:preparing), do: "badge-warning"
  defp status_color(:pending), do: "badge-ghost"
  defp status_color(:cancelled), do: "badge-ghost"
  defp status_color(:timed_out), do: "badge-error"
  defp status_color(:stale), do: "badge-ghost"
  defp status_color(_), do: "badge-ghost"

  defp step_class(:created, _run), do: "step-primary"
  defp step_class(:started, %{started_at: nil}), do: ""
  defp step_class(:started, _run), do: "step-primary"
  defp step_class(:completed, %{completed_at: nil, cancelled_at: nil}), do: ""
  defp step_class(:completed, %{status: :success}), do: "step-success"
  defp step_class(:completed, %{status: :failure}), do: "step-error"
  defp step_class(:completed, _run), do: "step-primary"

  defp terminal_label(:success), do: "Completed"
  defp terminal_label(:failure), do: "Failed"
  defp terminal_label(:cancelled), do: "Cancelled"
  defp terminal_label(:timed_out), do: "Timed Out"
  defp terminal_label(_), do: "Pending"

  defp format_dt(nil), do: "-"
  defp format_dt(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")

  defp model_label(%{agent_definition: %{runtime_profile: %{model: model}}})
       when is_binary(model) and model != "" do
    model
  end

  defp model_label(_), do: "-"

  defp format_timestamp(nil), do: ""
  defp format_timestamp(dt), do: Calendar.strftime(dt, "%H:%M:%S")

  defp log_level_color("error"), do: "text-error"
  defp log_level_color("warn"), do: "text-warning"
  defp log_level_color("info"), do: "text-info"
  defp log_level_color(_), do: "text-base-content/60"

  defp format_bytes(nil), do: "-"
  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"
end
