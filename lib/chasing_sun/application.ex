defmodule ChasingSun.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ChasingSunWeb.Telemetry,
      ChasingSun.Repo,
      {Oban, Application.fetch_env!(:chasing_sun, Oban)},
      {DNSCluster, query: Application.get_env(:chasing_sun, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ChasingSun.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: ChasingSun.Finch},
      # Start a worker by calling: ChasingSun.Worker.start_link(arg)
      # {ChasingSun.Worker, arg},
      # Start to serve requests, typically the last entry
      ChasingSunWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ChasingSun.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ChasingSunWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
