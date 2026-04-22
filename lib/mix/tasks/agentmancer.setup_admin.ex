defmodule Mix.Tasks.Agentmancer.SetupAdmin do
  @shortdoc "Creates the initial admin user"
  @moduledoc """
  Creates the initial admin user for Agentmancer.

  Reads ADMIN_EMAIL and ADMIN_PASSWORD from environment variables.
  If not set, prompts interactively.

  Idempotent: skips if the user already exists.

      mix agentmancer.setup_admin
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(_args) do
    email = System.get_env("ADMIN_EMAIL") || prompt("Admin email: ")
    password = System.get_env("ADMIN_PASSWORD") || prompt_secret("Admin password: ")

    case Agentmancer.Accounts.get_user_by_email(email) do
      nil ->
        case Agentmancer.Accounts.register_user(%{email: email, password: password}) do
          {:ok, _user} ->
            Mix.shell().info("Admin user created: #{email}")

          {:error, changeset} ->
            errors =
              Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)

            Mix.shell().error("Failed to create admin: #{inspect(errors)}")
        end

      _user ->
        Mix.shell().info("Admin user already exists: #{email}")
    end
  end

  defp prompt(message) do
    Mix.shell().prompt(message) |> String.trim()
  end

  defp prompt_secret(message) do
    if function_exported?(Mix.shell(), :prompt, 2) do
      Mix.shell().prompt(message) |> String.trim()
    else
      prompt(message)
    end
  end
end
