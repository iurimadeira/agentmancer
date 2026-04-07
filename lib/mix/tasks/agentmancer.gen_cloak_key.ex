defmodule Mix.Tasks.Agentmancer.GenCloakKey do
  @shortdoc "Generates a base64-encoded 32-byte AES key for Cloak encryption"
  @moduledoc """
  Generates a random 32-byte AES key and prints it as base64.

  Set this as the CLOAK_KEY environment variable.

      mix agentmancer.gen_cloak_key
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    key = :crypto.strong_rand_bytes(32) |> Base.encode64()
    Mix.shell().info(key)
  end
end
