defmodule Agentmancer.Runtime.RunServer do
  use GenServer, restart: :temporary

  require Logger

  alias Agentmancer.Execution
  alias Agentmancer.Runtime.LogBuffer
  alias Agentmancer.Workspace

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

    adapter = resolve_adapter(run)
    timeout_ms = resolve_timeout(run)

    workspace_spec = build_workspace_spec(run)

    case Workspace.setup(workspace_spec) do
      {:ok, workspace_ctx} ->
        {:ok, attempt} =
          Execution.create_attempt(run, %{
            status: :running,
            engine: to_string(adapter.capabilities().engine),
            engine_version: adapter.capabilities().version,
            worktree_path: workspace_ctx.worktree_path,
            started_at: DateTime.utc_now()
          })

        run_ctx = build_run_context(run, attempt, workspace_ctx)

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

            Execution.fail_run(run, %{error_message: "Adapter prepare failed: #{inspect(reason)}"})

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
    engine =
      case run do
        %{agent_definition: %{runtime_profile: %{engine: engine}}} -> engine
        _ -> :claude_code_cli
      end

    case engine do
      :codex_cli -> Agentmancer.Runtime.Adapters.CodexCLI
      :claude_code_cli -> Agentmancer.Runtime.Adapters.ClaudeCodeCLI
      _ -> Agentmancer.Runtime.Adapters.ClaudeCodeCLI
    end
  end

  defp resolve_timeout(run) do
    case run do
      %{agent_definition: %{runtime_profile: %{timeout_seconds: secs}}} when is_integer(secs) ->
        secs * 1_000

      _ ->
        600_000
    end
  end

  defp build_workspace_spec(run) do
    repo = run.repository
    version = run.agent_version

    %{
      run_id: run.id,
      repo_id: repo.id,
      clone_url: repo.clone_url,
      ref: run.branch || repo.default_branch || "main",
      head_sha: run.pr_head_sha,
      materialization: %{
        agents_md: version && version.system_prompt,
        mcp_config: nil,
        env_vars: %{},
        output_schema: version && version.output_schema
      }
    }
  end

  defp build_run_context(run, _attempt, workspace_ctx) do
    version = run.agent_version
    prompt = (run.input && run.input["prompt"]) || ""

    %{
      run_id: run.id,
      prompt: prompt,
      system_prompt: version && version.system_prompt,
      output_schema: version && version.output_schema,
      worktree_path: workspace_ctx.worktree_path,
      env_vars: %{},
      timeout_ms: resolve_timeout(run),
      model: nil,
      mcp_config_path: nil,
      sandbox_mode: :workspace_write,
      extra_args: []
    }
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
