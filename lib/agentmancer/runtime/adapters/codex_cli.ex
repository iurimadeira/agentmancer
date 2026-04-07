defmodule Agentmancer.Runtime.Adapters.CodexCLI do
  @behaviour Agentmancer.Runtime.EngineAdapter

  @impl true
  def capabilities do
    %{
      engine: "codex_cli",
      version: "0.1",
      supported: [:streaming, :tool_use, :cancellation],
      max_prompt_bytes: :unlimited
    }
  end

  @impl true
  def prepare_run(ctx) do
    args =
      ["exec", ctx.prompt, "--json", "--full-auto", "--ephemeral"] ++
        model_args(ctx.model) ++
        ctx.extra_args

    env =
      ctx.env_vars
      |> Enum.map(fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

    opts = [
      cd: String.to_charlist(ctx.worktree_path),
      env: env,
      args: args
    ]

    case System.find_executable("codex") do
      nil -> {:error, :codex_not_found}
      path -> {:ok, {path, args, opts}}
    end
  end

  @impl true
  def parse_stream_line(line) do
    case Jason.decode(line) do
      {:ok, %{"type" => "message"} = event} ->
        {:agent_event, event}

      {:ok, %{"type" => "function_call"} = event} ->
        {:agent_event, event}

      {:ok, %{"type" => "function_call_output"} = event} ->
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

    {structured_output, _session_id} = extract_final_output(stdout_lines)

    %{
      exit_code: exit_code,
      raw_output: raw_output,
      structured_output: structured_output,
      cost_usd: nil,
      num_turns: nil,
      session_id: nil,
      duration_ms: duration_ms
    }
  end

  @impl true
  def cancel_signal, do: :sigterm

  defp model_args(nil), do: []
  defp model_args(model), do: ["--model", model]

  defp extract_final_output(stdout_lines) do
    last_message =
      stdout_lines
      |> Enum.reverse()
      |> Enum.find_value(fn line ->
        case Jason.decode(line) do
          {:ok, %{"type" => "message", "role" => "assistant"} = msg} -> msg
          _ -> nil
        end
      end)

    case last_message do
      %{"content" => content} when is_list(content) ->
        text =
          content
          |> Enum.filter(&(&1["type"] == "output_text"))
          |> Enum.map_join("\n", & &1["text"])

        {try_parse_json(text), nil}

      _ ->
        {nil, nil}
    end
  end

  defp try_parse_json(text) do
    case Jason.decode(text) do
      {:ok, parsed} -> parsed
      _ -> nil
    end
  end
end
