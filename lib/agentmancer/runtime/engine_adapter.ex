defmodule Agentmancer.Runtime.EngineAdapter do
  @type capability :: :streaming | :structured_output | :tool_use | :mcp | :cancellation

  @type capabilities :: %{
          engine: String.t(),
          version: String.t(),
          supported: [capability()],
          max_prompt_bytes: pos_integer() | :unlimited
        }

  @type run_context :: %{
          run_id: Ecto.UUID.t(),
          prompt: String.t(),
          system_prompt: String.t() | nil,
          output_schema: map() | nil,
          worktree_path: String.t(),
          env_vars: %{String.t() => String.t()},
          timeout_ms: pos_integer(),
          model: String.t() | nil,
          mcp_config_path: String.t() | nil,
          sandbox_mode: :read_only | :workspace_write | :full_access,
          extra_args: [String.t()]
        }

  @type stream_event ::
          {:stdout, binary()}
          | {:stderr, binary()}
          | {:agent_event, map()}
          | {:exit, non_neg_integer()}

  @type run_result :: %{
          exit_code: non_neg_integer(),
          raw_output: String.t(),
          structured_output: map() | nil,
          cost_usd: float() | nil,
          num_turns: non_neg_integer() | nil,
          session_id: String.t() | nil,
          duration_ms: non_neg_integer()
        }

  @callback capabilities() :: capabilities()

  @callback prepare_run(run_context()) ::
              {:ok, {String.t(), [String.t()], keyword()}} | {:error, term()}

  @callback parse_stream_line(binary()) :: stream_event() | nil

  @callback normalize_result(non_neg_integer(), [binary()], [binary()], non_neg_integer()) ::
              run_result()

  @callback cancel_signal() :: :sigterm | :sigkill | :sigint
end
