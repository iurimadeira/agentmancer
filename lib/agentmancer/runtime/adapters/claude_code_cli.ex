defmodule Agentmancer.Runtime.Adapters.ClaudeCodeCLI do
  @behaviour Agentmancer.Runtime.EngineAdapter

  @impl true
  def capabilities do
    %{
      engine: "claude_code_cli",
      version: "0.1",
      supported: [:streaming, :structured_output, :tool_use, :mcp, :cancellation],
      max_prompt_bytes: :unlimited
    }
  end

  @impl true
  def prepare_run(ctx) do
    args =
      ["-p", ctx.prompt, "--output-format", "stream-json"] ++
        model_args(ctx.model) ++
        system_prompt_args(ctx.system_prompt) ++
        mcp_args(ctx.mcp_config_path) ++
        output_schema_args(ctx.output_schema) ++
        sandbox_args(ctx.sandbox_mode) ++
        ctx.extra_args

    env =
      ctx.env_vars
      |> Enum.map(fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

    opts = [
      cd: String.to_charlist(ctx.worktree_path),
      env: env,
      args: args
    ]

    case System.find_executable("claude") do
      nil -> {:error, :claude_not_found}
      path -> {:ok, {path, args, opts}}
    end
  end

  @impl true
  def parse_stream_line(line) do
    case Jason.decode(line) do
      {:ok, %{"type" => "init"} = event} ->
        {:agent_event, event}

      {:ok, %{"type" => "assistant"} = event} ->
        {:agent_event, event}

      {:ok, %{"type" => "tool_use"} = event} ->
        {:agent_event, event}

      {:ok, %{"type" => "tool_result"} = event} ->
        {:agent_event, event}

      {:ok, %{"type" => "result"} = event} ->
        {:agent_event, event}

      {:ok, %{"type" => "error"} = event} ->
        {:agent_event, event}

      {:ok, event} when is_map(event) ->
        {:agent_event, event}

      _ ->
        if String.trim(line) == "", do: nil, else: {:stdout, line}
    end
  end

  @impl true
  def normalize_result(exit_code, stdout_lines, _stderr_lines, duration_ms) do
    raw_output = Enum.join(stdout_lines, "\n")

    result_event = extract_result_event(stdout_lines)

    %{
      exit_code: exit_code,
      raw_output: raw_output,
      structured_output: get_in(result_event, ["result"]),
      cost_usd: get_in(result_event, ["cost_usd"]),
      num_turns: get_in(result_event, ["num_turns"]),
      session_id: get_in(result_event, ["session_id"]),
      duration_ms: duration_ms
    }
  end

  @impl true
  def cancel_signal, do: :sigint

  defp model_args(nil), do: []
  defp model_args(model), do: ["--model", model]

  defp system_prompt_args(nil), do: []
  defp system_prompt_args(prompt), do: ["--system-prompt", prompt]

  defp mcp_args(nil), do: []
  defp mcp_args(path), do: ["--mcp-config", path]

  defp output_schema_args(nil), do: []
  defp output_schema_args(_schema), do: ["--output-format", "stream-json"]

  defp sandbox_args(:read_only), do: ["--permission-mode", "read-only"]
  defp sandbox_args(:workspace_write), do: ["--permission-mode", "default"]
  defp sandbox_args(:full_access), do: ["--permission-mode", "full"]
  defp sandbox_args(_), do: []

  defp extract_result_event(stdout_lines) do
    stdout_lines
    |> Enum.reverse()
    |> Enum.find_value(%{}, fn line ->
      case Jason.decode(line) do
        {:ok, %{"type" => "result"} = event} -> event
        _ -> nil
      end
    end)
  end
end
