defmodule Agentmancer.Runtime.RunServer do
  use GenServer, restart: :temporary

  require Logger

  alias Agentmancer.Execution
  alias Agentmancer.Runtime.LogBuffer
  alias Agentmancer.RuntimeProfiles
  alias Agentmancer.Skills
  alias Agentmancer.Workspace

  @default_prompt "Execute the selected skill using the current repository context."

  defstruct [
    :run_id,
    :run,
    :attempt,
    :adapter,
    :port,
    :os_pid,
    :caller,
    :worktree_path,
    :log_buffer,
    :started_at,
    stdout_lines: [],
    stderr_lines: []
  ]

  # Client API

  def start_link(opts) do
    run_id = Keyword.fetch!(opts, :run_id)

    GenServer.start_link(__MODULE__, opts,
      name: {:via, Registry, {Agentmancer.RunRegistry, {:run, run_id}}}
    )
  end

  def cancel(run_id) do
    case Registry.lookup(Agentmancer.RunRegistry, {:run, run_id}) do
      [{pid, _}] -> GenServer.cast(pid, :cancel)
      [] -> {:error, :not_found}
    end
  end

  # Server callbacks

  @impl true
  def init(opts) do
    run_id = Keyword.fetch!(opts, :run_id)
    caller = Keyword.get(opts, :caller)

    state = %__MODULE__{
      run_id: run_id,
      caller: caller,
      started_at: System.monotonic_time(:millisecond)
    }

    {:ok, state, {:continue, :setup}}
  end

  @impl true
  def handle_continue(:setup, state) do
    run = Execution.get_run_with_associations!(state.run_id)

    workspace_spec = build_workspace_spec(run)

    case Workspace.setup(workspace_spec) do
      {:ok, workspace_ctx} ->
        with {:ok, skill} <- resolve_skill(run, workspace_ctx.worktree_path),
             :ok <-
               Workspace.materialize(workspace_ctx.worktree_path, %{
                 output_schema: skill.output_schema
               }),
             {:ok, run} <- maybe_snapshot_skill(run, skill) do
          adapter = resolve_adapter(run)
          timeout_ms = resolve_timeout(run)

          {:ok, attempt} =
            Execution.create_attempt(run, %{
              status: :running,
              engine: to_string(adapter.capabilities().engine),
              engine_version: adapter.capabilities().version,
              worktree_path: workspace_ctx.worktree_path,
              started_at: DateTime.utc_now()
            })

          run_ctx = build_run_context(run, skill, attempt, workspace_ctx)

          case adapter.prepare_run(run_ctx) do
            {:ok, {executable, args, _adapter_opts}} ->
              {:ok, _run} =
                Execution.update_run_status(run, :running, %{started_at: DateTime.utc_now()})

              port = open_port(executable, args, workspace_ctx)
              os_pid = Port.info(port)[:os_pid]
              log_buffer = LogBuffer.new(attempt.id, run.project_id)
              Process.send_after(self(), :timeout, timeout_ms)

              {:noreply,
               %{
                 state
                 | run: run,
                   attempt: attempt,
                   adapter: adapter,
                   port: port,
                   os_pid: os_pid,
                   worktree_path: workspace_ctx.worktree_path,
                   log_buffer: log_buffer
               }}

            {:error, reason} ->
              Logger.error("Run #{state.run_id}: adapter prepare failed: #{inspect(reason)}")

              Execution.fail_run(run, %{
                error_message: "Adapter prepare failed: #{inspect(reason)}"
              })

              notify_caller(state.caller, state.run_id, {:error, reason})
              {:stop, :normal, state}
          end
        else
          {:error, reason} ->
            Logger.error("Run #{state.run_id}: skill resolution failed: #{inspect(reason)}")

            Execution.fail_run(run, %{
              error_message: "Skill resolution failed: #{inspect(reason)}"
            })

            if workspace_ctx.worktree_path do
              Workspace.cleanup(state.run_id, workspace_ctx.worktree_path)
            end

            notify_caller(state.caller, state.run_id, {:error, reason})
            {:stop, :normal, state}
        end

      {:error, reason} ->
        Logger.error("Run #{state.run_id}: workspace setup failed: #{inspect(reason)}")
        Execution.fail_run(run, %{error_message: "Workspace setup failed: #{inspect(reason)}"})
        notify_caller(state.caller, state.run_id, {:error, reason})
        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_info({port, {:data, {:eol, line}}}, %{port: port} = state) do
    event = state.adapter.parse_stream_line(line)
    state = record_line(state, line, event)
    state = maybe_broadcast(state, event)
    {:noreply, state}
  end

  def handle_info({port, {:data, {:noeol, line}}}, %{port: port} = state) do
    state = %{state | stdout_lines: [line | state.stdout_lines]}
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, exit_code}}, %{port: port} = state) do
    duration_ms = System.monotonic_time(:millisecond) - state.started_at

    stdout_lines = Enum.reverse(state.stdout_lines)
    stderr_lines = Enum.reverse(state.stderr_lines)
    result = state.adapter.normalize_result(exit_code, stdout_lines, stderr_lines, duration_ms)

    log_buffer = LogBuffer.flush(state.log_buffer)
    state = %{state | log_buffer: log_buffer}

    attempt_status = if exit_code == 0, do: :success, else: :failure

    Execution.create_attempt(state.run, %{}) |> ignore_already_created()

    {:ok, _attempt} =
      state.attempt
      |> Execution.RunAttempt.changeset(%{
        status: attempt_status,
        exit_code: exit_code,
        completed_at: DateTime.utc_now(),
        duration_ms: duration_ms,
        error_message: if(exit_code != 0, do: "Exit code: #{exit_code}")
      })
      |> Agentmancer.Repo.update()

    if exit_code == 0 do
      Execution.complete_run(state.run, %{output: result.structured_output})
    else
      Execution.fail_run(state.run, %{error_message: "Exit code: #{exit_code}"})
    end

    Workspace.cleanup(state.run_id, state.worktree_path)
    notify_caller(state.caller, state.run_id, {:ok, result})

    broadcast_run_event(state.run_id, :completed, result)

    {:stop, :normal, state}
  end

  def handle_info(:timeout, state) do
    Logger.warning("Run #{state.run_id}: timed out, killing process")
    kill_process(state)
    Execution.update_run_status(state.run, :timed_out, %{error_message: "Run timed out"})
    {:noreply, state}
  end

  def handle_info(:flush_log_buffer, state) when is_nil(state.log_buffer), do: {:noreply, state}

  def handle_info(:flush_log_buffer, state) do
    {:noreply, %{state | log_buffer: LogBuffer.flush(state.log_buffer)}}
  end

  def handle_info({_port, {:data, _}}, state), do: {:noreply, state}

  def handle_info(msg, state) do
    Logger.debug("Run #{state.run_id}: unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_cast(:cancel, state) do
    Logger.info("Run #{state.run_id}: cancellation requested")
    kill_process(state)
    Execution.cancel_run(state.run)

    if state.attempt do
      state.attempt
      |> Execution.RunAttempt.changeset(%{
        status: :cancelled,
        completed_at: DateTime.utc_now()
      })
      |> Agentmancer.Repo.update()
    end

    if state.log_buffer, do: LogBuffer.flush(state.log_buffer)
    if state.worktree_path, do: Workspace.cleanup(state.run_id, state.worktree_path)
    notify_caller(state.caller, state.run_id, {:error, :cancelled})

    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.port && Port.info(state.port), do: kill_process(state)
    if state.log_buffer, do: LogBuffer.flush(state.log_buffer)
    if state.worktree_path, do: Workspace.cleanup(state.run_id, state.worktree_path)
    :ok
  end

  # Private helpers

  defp resolve_adapter(run) do
    case resolve_runtime_profile(run) do
      %{engine: :codex_cli} -> Agentmancer.Runtime.Adapters.CodexCLI
      %{engine: :claude_code_cli} -> Agentmancer.Runtime.Adapters.ClaudeCodeCLI
      _ -> Agentmancer.Runtime.Adapters.ClaudeCodeCLI
    end
  end

  defp resolve_timeout(run) do
    case resolve_runtime_profile(run) do
      %{timeout_seconds: secs} when is_integer(secs) ->
        secs * 1_000

      _ ->
        600_000
    end
  end

  defp resolve_model(run) do
    case resolve_runtime_profile(run) do
      %{model: model} when is_binary(model) and model != "" -> model
      _ -> nil
    end
  end

  defp resolve_runtime_profile(%{
         workflow_definition: %{runtime_profile: %Ecto.Association.NotLoaded{}},
         project: project
       }),
       do: resolve_project_runtime_profile(project)

  defp resolve_runtime_profile(%{workflow_definition: %{runtime_profile: runtime_profile}})
       when not is_nil(runtime_profile),
       do: runtime_profile

  defp resolve_runtime_profile(%{project: project}), do: resolve_project_runtime_profile(project)

  defp resolve_runtime_profile(_), do: nil

  defp resolve_project_runtime_profile(%{
         default_runtime_profile: %Ecto.Association.NotLoaded{},
         id: project_id
       }) do
    RuntimeProfiles.default_runtime_profile(%Agentmancer.Projects.Project{id: project_id})
  end

  defp resolve_project_runtime_profile(%{default_runtime_profile: runtime_profile})
       when not is_nil(runtime_profile),
       do: runtime_profile

  defp resolve_project_runtime_profile(project) when not is_nil(project) do
    RuntimeProfiles.default_runtime_profile(project)
  end

  defp resolve_project_runtime_profile(_), do: nil

  defp build_workspace_spec(run) do
    repo = run.repository

    %{
      run_id: run.id,
      repo_id: repo.id,
      clone_url: repo.clone_url,
      ref: run.branch || repo.default_branch || "main",
      head_sha: run.pr_head_sha
    }
  end

  defp build_run_context(run, skill, _attempt, workspace_ctx) do
    prompt = normalize_prompt(run)

    %{
      run_id: run.id,
      prompt: prompt,
      system_prompt: skill.body,
      output_schema: skill.output_schema,
      worktree_path: workspace_ctx.worktree_path,
      env_vars: %{},
      timeout_ms: resolve_timeout(run),
      model: resolve_model(run),
      mcp_config_path: nil,
      sandbox_mode: :workspace_write,
      extra_args: []
    }
  end

  defp normalize_prompt(%{input: %{"prompt" => prompt}}) when is_binary(prompt) and prompt != "",
    do: prompt

  defp normalize_prompt(_), do: @default_prompt

  defp resolve_skill(%{skill_body: body} = run, _worktree_path)
       when is_binary(body) and body != "" do
    {:ok,
     %Skills.Skill{
       source: run.skill_source,
       slug: run.skill_slug,
       name: run.skill_name || Skills.titleize_slug(run.skill_slug),
       body: body,
       description: get_in(run.skill_metadata || %{}, ["description"]),
       kind: get_in(run.skill_metadata || %{}, ["kind"]),
       tags: get_in(run.skill_metadata || %{}, ["tags"]) || [],
       icon: get_in(run.skill_metadata || %{}, ["icon"]),
       output_schema: get_in(run.skill_metadata || %{}, ["output_schema"]),
       suggested_trigger: get_in(run.skill_metadata || %{}, ["suggested_trigger"]) || %{},
       seed_default_workflow: false,
       metadata: run.skill_metadata || %{}
     }}
  end

  defp resolve_skill(%{skill_source: :global, skill_slug: slug}, _worktree_path) do
    Skills.fetch_global_skill(slug)
  end

  defp resolve_skill(
         %{skill_source: :repository, skill_slug: slug, repository: repo},
         worktree_path
       ) do
    Skills.fetch_repository_skill_from_worktree(worktree_path, slug, repo)
  end

  defp resolve_skill(_run, _worktree_path), do: {:error, :skill_not_configured}

  defp maybe_snapshot_skill(run, skill) do
    snapshot_attrs = %{
      skill_name: skill.name,
      skill_body: skill.body,
      skill_metadata:
        skill.metadata
        |> Map.put_new("description", skill.description)
        |> Map.put_new("kind", skill.kind)
        |> Map.put_new("tags", skill.tags)
        |> Map.put_new("icon", skill.icon)
        |> Map.put_new("output_schema", skill.output_schema)
        |> Map.put_new("suggested_trigger", skill.suggested_trigger)
    }

    Execution.update_run_skill_snapshot(run, snapshot_attrs)
  end

  defp open_port(executable, args, workspace_ctx) do
    Port.open({:spawn_executable, String.to_charlist(executable)}, [
      :binary,
      :exit_status,
      :use_stdio,
      :stderr_to_stdout,
      {:line, 1_048_576},
      {:args, Enum.map(args, &String.to_charlist/1)},
      {:cd, String.to_charlist(workspace_ctx.worktree_path)}
    ])
  end

  defp record_line(state, line, event) do
    state = %{state | stdout_lines: [line | state.stdout_lines]}

    level =
      case event do
        {:stderr, _} -> "error"
        {:agent_event, %{"type" => "error"}} -> "error"
        _ -> "info"
      end

    text =
      case event do
        {:agent_event, evt} -> Jason.encode!(evt)
        _ -> line
      end

    {log_buffer, _} = LogBuffer.append(state.log_buffer, level, text)
    %{state | log_buffer: log_buffer}
  end

  defp maybe_broadcast(state, {:agent_event, event}) do
    broadcast_run_event(state.run_id, :agent_event, event)
    state
  end

  defp maybe_broadcast(state, {:stdout, text}) do
    broadcast_run_event(state.run_id, :stdout, text)
    state
  end

  defp maybe_broadcast(state, _), do: state

  defp broadcast_run_event(run_id, event_type, payload) do
    Phoenix.PubSub.broadcast(
      Agentmancer.PubSub,
      "run:#{run_id}",
      {event_type, payload}
    )
  end

  defp kill_process(%{os_pid: pid}) when is_integer(pid) do
    System.cmd("kill", ["-TERM", "-#{pid}"], stderr_to_stdout: true)
  catch
    _, _ -> :ok
  end

  defp kill_process(_), do: :ok

  defp notify_caller(nil, _run_id, _result), do: :ok

  defp notify_caller(caller, run_id, result) do
    send(caller, {:run_complete, run_id, result})
  end

  defp ignore_already_created({:ok, _}), do: :ok
  defp ignore_already_created({:error, _}), do: :ok
end
