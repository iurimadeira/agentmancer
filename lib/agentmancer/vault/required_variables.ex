defmodule Agentmancer.Vault.RequiredVariables do
  @required_vars [
    %{
      key: "ANTHROPIC_API_KEY",
      label: "Anthropic API Key",
      description: "API key for Claude Code CLI engine.",
      secret: true
    },
    %{
      key: "GITHUB_TOKEN",
      label: "GitHub Token",
      description: "Personal access token for GitHub operations.",
      secret: true
    }
  ]

  def list, do: @required_vars
  def keys, do: Enum.map(@required_vars, & &1.key)
end
