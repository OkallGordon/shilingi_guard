defmodule ShilingiGuard.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ShilingiGuardWeb.Telemetry,
      ShilingiGuard.Repo,
      {DNSCluster, query: Application.get_env(:shilingi_guard, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ShilingiGuard.PubSub},
      # Start a worker by calling: ShilingiGuard.Worker.start_link(arg)
      # {ShilingiGuard.Worker, arg},
      # Start to serve requests, typically the last entry
      ShilingiGuardWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ShilingiGuard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ShilingiGuardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
