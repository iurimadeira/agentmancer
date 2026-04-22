defmodule Agentmancer.Workspace.Materializer do
  @type config :: %{
          output_schema: map() | nil
        }

  @spec materialize(String.t(), config()) :: :ok | {:error, term()}
  def materialize(worktree_path, config) do
    write_output_schema(worktree_path, config[:output_schema] || config["output_schema"])
  end

  defp write_output_schema(_worktree_path, nil), do: :ok

  defp write_output_schema(worktree_path, output_schema) do
    path = Path.join(worktree_path, ".output-schema.json")
    File.write(path, Jason.encode!(output_schema, pretty: true))
  end
end
