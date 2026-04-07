defmodule Agentmancer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AgentmancerWeb.Telemetry,
      Agentmancer.Repo,
      {DNSCluster, query: Application.get_env(:agentmancer, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Agentmancer.PubSub},
      {Oban, Application.fetch_env!(:agentmancer, Oban)},
      Agentmancer.Vault.Cipher,
      {Registry, keys: :unique, name: Agentmancer.RunRegistry},
      {Registry, keys: :unique, name: Agentmancer.LockRegistry},
      {DynamicSupervisor, name: Agentmancer.RunSupervisor, strategy: :one_for_one},
      {Task.Supervisor, name: Agentmancer.TaskSupervisor},
      AgentmancerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Agentmancer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AgentmancerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
