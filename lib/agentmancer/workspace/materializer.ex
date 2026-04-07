defmodule Agentmancer.Workspace.Materializer do
  require Logger

  @type config :: %{
          agents_md: String.t() | nil,
          mcp_config: map() | nil,
          env_vars: %{String.t() => String.t()},
          output_schema: map() | nil
        }

  @spec materialize(String.t(), config()) :: :ok | {:error, term()}
  def materialize(worktree_path, config) do
    with :ok <- write_agents_md(worktree_path, config[:agents_md] || config["agents_md"]),
         :ok <- write_mcp_config(worktree_path, config[:mcp_config] || config["mcp_config"]),
         :ok <-
           write_output_schema(
             worktree_path,
             config[:output_schema] || config["output_schema"]
           ) do
      :ok
    end
  end

  defp write_agents_md(_worktree_path, nil), do: :ok

  defp write_agents_md(worktree_path, agents_md) do
    path = Path.join(worktree_path, "AGENTS.md")
    File.write(path, agents_md)
  end

  defp write_mcp_config(_worktree_path, nil), do: :ok

  defp write_mcp_config(worktree_path, mcp_config) do
    claude_dir = Path.join(worktree_path, ".claude")
    File.mkdir_p!(claude_dir)

    path = Path.join(claude_dir, "settings.local.json")
    File.write(path, Jason.encode!(mcp_config, pretty: true))
  end

  defp write_output_schema(_worktree_path, nil), do: :ok

  defp write_output_schema(worktree_path, output_schema) do
    path = Path.join(worktree_path, ".output-schema.json")
    File.write(path, Jason.encode!(output_schema, pretty: true))
  end
end
