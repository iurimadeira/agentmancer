defmodule Agentmancer.Repo do
  use Ecto.Repo,
    otp_app: :agentmancer,
    adapter: Ecto.Adapters.Postgres
end
